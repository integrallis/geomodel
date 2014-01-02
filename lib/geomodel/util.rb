module Geomodel::Util
  
  def self.merge_in_place(target, arrays, dup_func = nil, comp_func = nil)
    arrays.each do |array| 
      array.each do |element|
        target.push(element) 
      end
    end

    comp_func.nil? ? target.sort! : target.sort!(&comp_func)
    dup_func.nil? ? target.uniq! : target.uniq!(&dup_func)
  end
  
  # Returns the edges of the rectangular region containing all of the
  # given geocells, sorted by distance from the given point, along with
  # the actual distances from the point to these edges.
  # 
  # Args:
  #   cells: The cells (should be adjacent) defining the rectangular region
  #       whose edge distances are requested.
  #   point: The point that should determine the edge sort order.
  # 
  # Returns:
  #   A list of (direction, distance) tuples, where direction is the edge
  #   and distance is the distance from the point to that edge. A direction
  #   value of (0,-1), for example, corresponds to the South edge of the
  #   rectangular region containing all of the given geocells.
  # 
  def self.distance_sorted_edges(cells, point)

    # TODO(romannurik): Assert that lat,lon are actually inside the geocell.
    boxes = cells.map { |cell| Geomodel::GeoCell.compute_box(cell) }

    max_box = Geomodel::Types::Box.new(
      boxes.map(&:north).max,
      boxes.map(&:east).max,
      boxes.map(&:south).max,
      boxes.map(&:west).max
    )
    
    dist_south = Geomodel::Math.distance(Geomodel::Types::Point.new(max_box.south, point.longitude), point)
    dist_north = Geomodel::Math.distance(Geomodel::Types::Point.new(max_box.north, point.longitude), point)
    dist_west = Geomodel::Math.distance(Geomodel::Types::Point.new(point.latitude, max_box.west), point)
    dist_east = Geomodel::Math.distance(Geomodel::Types::Point.new(point.latitude, max_box.east), point)
        
    [
      [Geomodel::GeoCell::SOUTH, dist_south], [Geomodel::GeoCell::NORTH, dist_north], [Geomodel::GeoCell::WEST, dist_west], [Geomodel::GeoCell::EAST, dist_east]
    ].sort { |x, y| x[1] <=> y[1] }.transpose
  end
  
end