require "geomodel/version"
require "geomodel/geomath"
require "geomodel/geotypes"
require "geomodel/geocell"
require "geomodel/util"
require 'set'

module Geomodel
  
  # The default cost function, used if none is provided              
  DEFAULT_COST_FUNCTION = lambda do |num_cells, resolution|
    num_cells > (Geomodel::GeoCell::GEOCELL_GRID_SIZE ** 2) ? 1e10000 : 0
  end
  
  # Retrieve the geocells to be used in a bounding box query
  # Something like geocells IN (...)
  # 
  # Args:
  #
  #   bbox: A geotypes.Box indicating the bounding box to filter entities by.
  #   cost_function: An optional function that accepts two arguments:
  #       * num_cells: the number of cells to search
  #       * resolution: the resolution of each cell to search
  #       and returns the 'cost' of querying against this number of cells
  #       at the given resolution.
  def self.geocells_for_bounding_box(bounding_box, cost_function = nil)
    cost_function = DEFAULT_COST_FUNCTION if cost_function.nil?
    Geomodel::GeoCell.best_bbox_search_cells(bounding_box, cost_function)
  end
  
  # Given a result set from your datastore (a query you filtered with
  # #geocells_for_bounding_box) it will filter the records that land outside
  # of the given bounding box (generally you'll use the same bounding box used
  # in #geocells_for_bounding_box)
  def self.filter_result_set_by_bounding_box(bounding_box, result_set)
    result_set.select do |row|
      row.latitude >= bounding_box.south &&
      row.latitude <= bounding_box.north &&
      row.longitude >= bounding_box.west &&
      row.longitude <= bounding_box.east
    end
  end
  
  #   center: A geotypes.Point or db.GeoPt indicating the center point around
  #       which to search for matching entities.
  #   max_results: An int indicating the maximum number of desired results.
  #       The default is 10, and the larger this number, the longer the fetch
  #       will take.
  #   max_distance: An optional number indicating the maximum distance to
  #       search, in meters.
  def self.proximity_fetch(center, query_runner, max_results = 10, max_distance = 0)
    results = []
  
    searched_cells = Set.new
    
    # The current search geocell containing the lat,lon.
    cur_containing_geocell = Geomodel::GeoCell.compute(center)
    
    # The currently-being-searched geocells.
    # NOTES:
    #     * Start with max possible.
    #     * Must always be of the same resolution.
    #     * Must always form a rectangular region.
    #     * One of these must be equal to the cur_containing_geocell.
    cur_geocells = [cur_containing_geocell]
  
    closest_possible_next_result_dist = 0
    
    # Assumes both a and b are lists of (entity, dist) tuples, *sorted by dist*.
    # NOTE: This is an in-place merge, and there are guaranteed
    # no duplicates in the resulting list.
    
    cmp_fn = lambda do |x, y| 
      (!x.empty? && !y.empty?) ? x[1] <=> y[1] : 0
    end
    
    dup_fn = lambda do |x| 
      (x.nil? || x.empty?) ? nil : x[0].id 
    end # assuming the the element responds to #id
  
    sorted_edges = [[0,0]]
    sorted_edge_distances = [0]
    
    while !cur_geocells.empty?
      closest_possible_next_result_dist = sorted_edge_distances[0]
      
      break if max_distance && closest_possible_next_result_dist > max_distance
  
      cur_geocells_unique = cur_geocells - searched_cells.to_a
  
      # Run query on the next set of geocells.
      cur_resolution = cur_geocells[0].size

      # Update results and sort.
      new_results = query_runner.call(cur_geocells_unique)
  
      searched_cells.merge(cur_geocells)
  
      # Begin storing distance from the search result entity to the
      # search center along with the search result itself, in a tuple.
      new_results = new_results.map { |entity|  [entity, Geomodel::Math.distance(center, entity.location)] }
      new_results.sort! { |x, y| (!x.empty? && !y.empty?) ? x[1] <=> y[1] : 0 }
      new_results = new_results[0...max_results]
  
      # Merge new_results into results or the other way around, depending on
      # which is larger.
      if results.size > new_results.size
        Geomodel::Util.merge_in_place(results, [new_results], dup_fn, cmp_fn)
      else
        Geomodel::Util.merge_in_place(new_results, [results], dup_fn, cmp_fn)
        results = new_results
      end

      results = results[0...max_results]
  
      sorted_edges, sorted_edge_distances = Geomodel::Util.distance_sorted_edges(cur_geocells, center)
  
      if results.empty? || cur_geocells.size == 4
        # Either no results (in which case we optimize by not looking at adjacents, go straight to the parent) 
        # or we've searched 4 adjacent geocells, in which case we should now search the parents of those
        # geocells.
        cur_containing_geocell = cur_containing_geocell[0...-1]
        cur_geocells = cur_geocells.map { |cell| cell[0...-1] }   
        break if !cur_geocells.empty? || !cur_geocells[0] # Done with search, we've searched everywhere.
      elsif cur_geocells.size == 1
        # Get adjacent in one direction.
        # TODO(romannurik): Watch for +/- 90 degree latitude edge case geocells.
        nearest_edge = sorted_edges[0]
        cur_geocells << Geomodel::GeoCell.adjacent(cur_geocells[0], nearest_edge)
      elsif cur_geocells.size == 2
        # Get adjacents in perpendicular direction.
        nearest_edge = Geomodel::Util.distance_sorted_edges([cur_containing_geocell], center)[0][0]
        if nearest_edge[0] == 0
          # Was vertical, perpendicular is horizontal.
          perpendicular_nearest_edge = sorted_edges.keep_if { |x| x[0] != 0 }.first
        else
          # Was horizontal, perpendicular is vertical.
          perpendicular_nearest_edge = sorted_edges.keep_if { |x| x[0] == 0 }.first
        end
        
        cur_geocells.concat(
          cur_geocells.map { |cell| Geomodel::GeoCell.adjacent(cell, perpendicular_nearest_edge) } 
        )
      end
      
      # We don't have enough items yet, keep searching.
      next if results.size < max_results
  
      # If the currently max_results'th closest item is closer than any
      # of the next test geocells, we're done searching.
      current_farthest_returnable_result_dist = Geomodel::Math.distance(center, results[max_results - 1][0].location)
      break if (closest_possible_next_result_dist >= current_farthest_returnable_result_dist)
    end
    
    results[0...max_results].keep_if { |result| max_distance == 0 || result.last < max_distance }  
  end
  
end
