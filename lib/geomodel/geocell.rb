module Geomodel
  
  # Defines the notion of 'geocells' and exposes methods to operate on them.
  # 
  # A geocell is a hexadecimal string that defines a two dimensional rectangular
  # region inside the [-90,90] x [-180,180] latitude/longitude space. A geocell's
  # 'resolution' is its length. For most practical purposes, at high resolutions,
  # geocells can be treated as single points.
  # 
  # Much like geohashes [see http://en.wikipedia.org/wiki/Geohash], geocells are
  # hierarchical, in that any prefix of a geocell is considered its ancestor, with
  # geocell[:-1] being geocell's immediate parent cell.
  # 
  # To calculate the rectangle of a given geocell string, first divide the
  # [-90,90] x [-180,180] latitude/longitude space evenly into a 4x4 grid like so:
  # 
  #              +---+---+---+---+ [90, 180]
  #              | a | b | e | f |
  #              +---+---+---+---+
  #              | 8 | 9 | c | d |
  #              +---+---+---+---+
  #              | 2 | 3 | 6 | 7 |
  #              +---+---+---+---+
  #              | 0 | 1 | 4 | 5 |
  #   [-90,-180] +---+---+---+---+
  # 
  # NOTE: The point [0, 0] is at the intersection of grid cells 3, 6, 9 and c. And,
  #       for example, cell 7 should be the sub-rectangle from
  #       [-45, 90] to [0, 180].
  # 
  # Calculate the sub-rectangle for the first character of the geocell string and
  # re-divide this sub-rectangle into another 4x4 grid. For example, if the geocell
  # string is '78a', we will re-divide the sub-rectangle like so:
  # 
  #                .                   .
  #                .                   .
  #            . . +----+----+----+----+ [0, 180]
  #                | 7a | 7b | 7e | 7f |
  #                +----+----+----+----+
  #                | 78 | 79 | 7c | 7d |
  #                +----+----+----+----+
  #                | 72 | 73 | 76 | 77 |
  #                +----+----+----+----+
  #                | 70 | 71 | 74 | 75 |
  #   . . [-45,90] +----+----+----+----+
  #                .                   .
  #                .                   .
  # 
  # Continue to re-divide into sub-rectangles and 4x4 grids until the entire
  # geocell string has been exhausted. The final sub-rectangle is the rectangular
  # region for the geocell.
  #
  module GeoCell
    # Geocell algorithm constants.
    GEOCELL_GRID_SIZE = 4
    GEOCELL_ALPHABET = '0123456789abcdef'

    # The maximum *practical* geocell resolution.
    MAX_GEOCELL_RESOLUTION = 13

    # The maximum number of geocells to consider for a bounding box search.
    MAX_FEASIBLE_BBOX_SEARCH_CELLS = 300

    # Direction enumerations.
    NORTHWEST = [-1, 1]
    NORTH = [0, 1]
    NORTHEAST = [1, 1]
    EAST = [1, 0]
    SOUTHEAST = [1, -1]
    SOUTH = [0, -1]
    SOUTHWEST = [-1, -1]
    WEST = [-1, 0]
    
    def self.generate_geocells(point)
      geocell_max = self.compute(point, MAX_GEOCELL_RESOLUTION)
      
      (1..MAX_GEOCELL_RESOLUTION).map do |resolution|
        self.compute(point, resolution)
      end
    end
    
    # Returns an efficient set of geocells to search in a bounding box query.
    # 
    # This method is guaranteed to return a set of geocells having the same
    # resolution.
    # 
    # Args:
    #   bbox: A geotypes.Box indicating the bounding box being searched.
    #   cost_function: A function that accepts two arguments:
    #       * num_cells: the number of cells to search
    #       * resolution: the resolution of each cell to search
    #       and returns the 'cost' of querying against this number of cells
    #       at the given resolution.
    # 
    # Returns:
    #   A list of geocell strings that contain the given box.
    #
    def self.best_bbox_search_cells(bbox, cost_function)

      cell_ne = compute(bbox.north_east, MAX_GEOCELL_RESOLUTION)
      cell_sw = compute(bbox.south_west, MAX_GEOCELL_RESOLUTION)

      # The current lowest BBOX-search cost found; start with practical infinity.
      min_cost = 1e10000

      # The set of cells having the lowest calculated BBOX-search cost.
      min_cost_cell_set = nil

      # First find the common prefix, if there is one.. this will be the base
      # resolution.. i.e. we don't have to look at any higher resolution cells.
      min_resolution = common_prefix([cell_sw, cell_ne]).size

      # Iteravely calculate all possible sets of cells that wholely contain
      # the requested bounding box.
      (min_resolution..(MAX_GEOCELL_RESOLUTION + 1)).each do |cur_resolution|
        cur_ne = cell_ne[0...cur_resolution]
        cur_sw = cell_sw[0...cur_resolution]

        num_cells = interpolation_count(cur_ne, cur_sw)
        next if num_cells > MAX_FEASIBLE_BBOX_SEARCH_CELLS
          
        cell_set = interpolate(cur_ne, cur_sw).sort
        simplified_cells = []

        cost = cost_function.call(cell_set.size, cur_resolution)

        # TODO(romannurik): See if this resolution is even possible, as in the
        # future cells at certain resolutions may not be stored.
        if cost <= min_cost
          min_cost = cost
          min_cost_cell_set = cell_set
        else
          # Once the cost starts rising, we won't be able to do better, so abort.
          break
        end
      end

      min_cost_cell_set
    end

    # Determines whether the given cells are collinear along a dimension.
    # 
    # Returns True if the given cells are in the same row (column_test=False)
    # or in the same column (column_test=True).
    # 
    # Args:
    #   cell1: The first geocell string.
    #   cell2: The second geocell string.
    #   column_test: A boolean, where False invokes a row collinearity test
    #       and 1 invokes a column collinearity test.
    # 
    # Returns:
    #   A bool indicating whether or not the given cells are collinear in the given
    #   dimension.
    #
    def self.collinear(cell1, cell2, column_test)
      upto = [cell1.size, cell2.size].min - 1
      
      (0..upto).each do |i|
        x1, y1 = subdiv_xy(cell1[i])
        x2, y2 = subdiv_xy(cell2[i])
     
        # Check row collinearity (assure y's are always the same).
        return false if (!column_test && y1 != y2)

        # Check column collinearity (assure x's are always the same).
        return false if (column_test && x1 != x2)
      end
      
      true
    end

    # Calculates the grid of cells formed between the two given cells.
    # 
    # Generates the set of cells in the grid created by interpolating from the
    # given Northeast geocell to the given Southwest geocell.
    # 
    # Assumes the Northeast geocell is actually Northeast of Southwest geocell.
    # 
    # Arguments:
    #   cell_ne: The Northeast geocell string.
    #   cell_sw: The Southwest geocell string.
    # 
    # Returns:
    #   A list of geocell strings in the interpolation.
    # 
    def self.interpolate(cell_ne, cell_sw)
      # 2D array, will later be flattened.
      cell_set = [[cell_sw]]

      # First get adjacent geocells across until Southeast--collinearity with
      # Northeast in vertical direction (0) means we're at Southeast.
      while !collinear(cell_set.first.last, cell_ne, true)
        cell_tmp = adjacent(cell_set.first.last, [1, 0])
        cell_set.first << cell_tmp unless cell_tmp.nil?
      end

      # Then get adjacent geocells upwards.
      while cell_set.last.last != cell_ne
        cell_tmp_row = cell_set.last.map { |g| adjacent(g, [0, 1]) }
        cell_set << cell_tmp_row unless cell_tmp_row.first.nil? 
      end
      
      # Flatten cell_set, since it's currently a 2D array.
      cell_set.flatten
    end   

    # Computes the number of cells in the grid formed between two given cells.
    # 
    # Computes the number of cells in the grid created by interpolating from the
    # given Northeast geocell to the given Southwest geocell. Assumes the Northeast
    # geocell is actually Northeast of Southwest geocell.
    # 
    # Arguments:
    #   cell_ne: The Northeast geocell string.
    #   cell_sw: The Southwest geocell string.
    # 
    # Returns:
    #   An int, indicating the number of geocells in the interpolation.
    # 
    def self.interpolation_count(cell_ne, cell_sw)

      bbox_ne = compute_box(cell_ne)
      bbox_sw = compute_box(cell_sw)

      cell_lat_span = bbox_sw.north - bbox_sw.south
      cell_lon_span = bbox_sw.east - bbox_sw.west

      num_cols = ((bbox_ne.east - bbox_sw.west) / cell_lon_span).to_i
      num_rows = ((bbox_ne.north - bbox_sw.south) / cell_lat_span).to_i

      num_cols * num_rows
    end

    # Calculates all of the given geocell's adjacent geocells.
    # 
    # Args:
    #   cell: The geocell string for which to calculate adjacent/neighboring cells.
    # 
    # Returns:
    #   A list of 8 geocell strings and/or None values indicating adjacent cells.
    #
    def self.all_adjacents(cell)
      [NORTHWEST, NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST].map { |d| adjacent(cell, d)}
    end

    # Calculates the geocell adjacent to the given cell in the given direction.
    # 
    # Args:
    #   cell: The geocell string whose neighbor is being calculated.
    #   dir: An (x, y) tuple indicating direction, where x and y can be -1, 0, or 1.
    #       -1 corresponds to West for x and South for y, and
    #        1 corresponds to East for x and North for y.
    #       Available helper constants are NORTH, EAST, SOUTH, WEST,
    #       NORTHEAST, NORTHWEST, SOUTHEAST, and SOUTHWEST.
    # 
    # Returns:
    #   The geocell adjacent to the given cell in the given direction, or None if
    #   there is no such cell.
    # 
    def self.adjacent(cell, dir)
      return nil if cell.nil?

      dx = dir[0]
      dy = dir[1]

      cell_adj_arr = cell.split(//)  # Split the geocell string characters into a list.
      i = cell_adj_arr.size - 1

      while i >= 0 && (dx != 0 or dy != 0)
        x, y = subdiv_xy(cell_adj_arr[i])

        # Horizontal adjacency.
        if dx == -1  # Asking for left.
          if x == 0  # At left of parent cell.
            x = GEOCELL_GRID_SIZE - 1  # Becomes right edge of adjacent parent.
          else
            x -= 1  # Adjacent, same parent.
            dx = 0  # Done with x.
          end
        elsif dx == 1  # Asking for right.
          if x == GEOCELL_GRID_SIZE - 1  # At right of parent cell.
            x = 0  # Becomes left edge of adjacent parent.
          else
            x += 1  # Adjacent, same parent.
            dx = 0  # Done with x.
          end
        end

        # Vertical adjacency.
        if dy == 1  # Asking for above.
          if y == GEOCELL_GRID_SIZE - 1  # At top of parent cell.
            y = 0  # Becomes bottom edge of adjacent parent.
          else
            y += 1  # Adjacent, same parent.
            dy = 0  # Done with y.
          end
        elsif dy == -1  # Asking for below.
          if y == 0  # At bottom of parent cell.
            y = GEOCELL_GRID_SIZE - 1  # Becomes top edge of adjacent parent.
          else
            y -= 1  # Adjacent, same parent.
            dy = 0  # Done with y.
          end
        end

        cell_adj_arr[i] = subdiv_char([x,y])
        i -= 1
      end
      
      # If we're not done with y then it's trying to wrap vertically,
      # which is a failure.
      return nil if dy != 0

      # At this point, horizontal wrapping is done inherently.
      cell_adj_arr.join('')
    end

    # Returns whether or not the given cell contains the given point.
    def self.contains_point(cell, point)
      compute(point, cell.size) == cell
    end

    # Returns the shortest distance between a point and a geocell bounding box.
    # 
    # If the point is inside the cell, the shortest distance is always to a 'edge'
    # of the cell rectangle. If the point is outside the cell, the shortest distance
    # will be to either a 'edge' or 'corner' of the cell rectangle.
    # 
    # Returns:
    #   The shortest distance from the point to the geocell's rectangle, in meters.
    #
    def self.point_distance(cell, point)
      bbox = compute_box(cell)

      between_w_e = bbox.west <= point.lon && point.lon <= bbox.east
      between_n_s = bbox.south <= point.lat && point.lat <= bbox.north

      if between_w_e
        if between_n_s
          # Inside the geocell.
          return [Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.south, point.lon)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.north, point.lon)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(point.lat, bbox.east)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(point.lat, bbox.west))].min
        else
          return [Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.south, point.lon)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.north, point.lon))].min
        end
      else
        if between_n_s
          return [Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(point.lat, bbox.east)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(point.lat, bbox.west))]
        else
          # TODO(romannurik): optimize
          return [Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.south, bbox.east)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.north, bbox.east)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.south, bbox.west)),
                  Geocoder::GeoMath.distance(point, Geomodel::Types::Point.new(bbox.north, bbox.west))]
        end
      end
    end

    # Computes the geocell containing the given point to the given resolution.
    # 
    # This is a simple 16-tree lookup to an arbitrary depth (resolution).
    # 
    # Args:
    #   point: The geotypes.Point to compute the cell for.
    #   resolution: An int indicating the resolution of the cell to compute.
    # 
    # Returns:
    #   The geocell string containing the given point, of length <resolution>.
    # 
    def self.compute(point, resolution = MAX_GEOCELL_RESOLUTION)
      north = 90.0
      south = -90.0
      east = 180.0
      west = -180.0

      cell = ''
      while cell.size < resolution
        subcell_lon_span = (east - west) / GEOCELL_GRID_SIZE
        subcell_lat_span = (north - south) / GEOCELL_GRID_SIZE

        x = [(GEOCELL_GRID_SIZE * (point.longitude - west) / (east - west)).to_i, 
             GEOCELL_GRID_SIZE - 1].min
        y = [(GEOCELL_GRID_SIZE * (point.latitude - south) / (north - south)).to_i,
             GEOCELL_GRID_SIZE - 1].min

        cell += subdiv_char([x,y])

        south += subcell_lat_span * y
        north = south + subcell_lat_span

        west += subcell_lon_span * x
        east = west + subcell_lon_span
      end

      cell
    end

    # Computes the rectangular boundaries (bounding box) of the given geocell.
    # 
    # Args:
    #   cell: The geocell string whose boundaries are to be computed.
    # 
    # Returns:
    #   A geotypes.Box corresponding to the rectangular boundaries of the geocell.
    # 
    def self.compute_box(cell)
      return nil if cell.nil?

      bbox = Geomodel::Types::Box.new(90.0, 180.0, -90.0, -180.0)
      
      cell_copy = cell.clone

      while cell_copy.size > 0
        subcell_lon_span = (bbox.east - bbox.west) / GEOCELL_GRID_SIZE
        subcell_lat_span = (bbox.north - bbox.south) / GEOCELL_GRID_SIZE

        x, y = subdiv_xy(cell_copy[0])

        bbox = Geomodel::Types::Box.new(bbox.south + subcell_lat_span * (y + 1),
                                        bbox.west  + subcell_lon_span * (x + 1),
                                        bbox.south + subcell_lat_span * y,
                                        bbox.west  + subcell_lon_span * x)

        cell_copy.slice!(0)
      end
      
      bbox
    end

    # Returns whether or not the given geocell string defines a valid geocell.
    def self.is_valid(cell)
      !cell.nil? && 
      cell.size > 0 && 
      cell.split(//).inject(true) { |val, c| val && GEOCELL_ALPHABET.include?(c) }
    end

    # Calculates the immediate children of the given geocell.
    # 
    # For example, the immediate children of 'a' are 'a0', 'a1', ..., 'af'.
    # 
    def self.children(cell)
      GEOCELL_ALPHABET.map { |chr| cell + chr }
    end

    # Returns the (x, y) of the geocell character in the 4x4 alphabet grid.
    # NOTE: This only works for grid size 4.
    def self.subdiv_xy(char)
      char = GEOCELL_ALPHABET.index(char)
      [(char & 4) >> 1 | (char & 1) >> 0, (char & 8) >> 2 | (char & 2) >> 1]
    end

    # Returns the geocell character in the 4x4 alphabet grid at pos. (x, y).
    # NOTE: This only works for grid size 4.
    def self.subdiv_char(pos)
      GEOCELL_ALPHABET[(pos[1] & 2) << 2 | (pos[0] & 2) << 1 | (pos[1] & 1) << 1 | (pos[0] & 1) << 0]
    end
    
    def self.common_prefix(list)
      /\A(.*).*(\n\1.*)*\Z/.match(list.join("\n"))[1]
    end
  end
end