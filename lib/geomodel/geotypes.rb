module Geomodel::Types
  
  # A two-dimensional point in the [-90,90] x [-180,180] lat/lon space.
  # 
  # Attributes:
  #   lat: A float in the range [-90,90] indicating the point's latitude.
  #   lon: A float in the range [-180,180] indicating the point's longitude.
  # 
  class Point
    
    attr_reader :latitude, :longitude
    
    alias_method :lat, :latitude
    alias_method :lon, :longitude
    
    def initialize(latitude, longitude)
      if -90 > latitude || latitude > 90
        raise ArgumentError.new("Latitude must be in [-90, 90]") 
      else
        @latitude = latitude
      end 
      
      if -180 > longitude || longitude > 180
        raise ArgumentError.new("Longitude must be in [-180, 180]") 
      else
        @longitude = longitude
      end        
    end
    
    def ==(point)
      (@latitude === point.latitude) && (@longitude === point.longitude)
    end
    
    def to_s
      "(#{@latitude}, #{@longitude})"
    end
    
  end
  
  #   A two-dimensional rectangular region defined by NE and SW points.
  # 
  #   Attributes:
  #     north_east: A read-only geotypes.Point indicating the box's Northeast
  #         coordinate.
  #     south_west: A read-only geotypes.Point indicating the box's Southwest
  #         coordinate.
  #     north: A float indicating the box's North latitude.
  #     east: A float indicating the box's East longitude.
  #     south: A float indicating the box's South latitude.
  #     west: A float indicating the box's West longitude.
  # 
  class Box
    attr_reader :north_east, :south_west
    
    def initialize(north, east, south, west)
      south, north = north, south if south > north
      
      # Don't swap east and west to allow disambiguation of
      # antimeridian crossing.
      @north_east = Point.new(north, east)
      @south_west = Point.new(south, west)
    end
    
    def north=(north)
      raise ArgumentError.new("Latitude must be north of box's south latitude") if north < @south_west.latitude
      @north_east.latitude = north
    end
    
    def east=(east)
      @north_east.longitude = east
    end
    
    def south=(south)
      raise ArgumentError.new("Latitude must be south of box's north latitude") if south > @south_west.latitude
      @south_west.latitude = south
    end
    
    def west=(west)
      @south_west.longitude = west
    end
    
    def north
      @north_east.latitude
    end
    
    def east
      @north_east.longitude
    end
    
    def south
      @south_west.latitude
    end
    
    def west
      @south_west.longitude
    end
    
    def ==(box)
      (@north_east === box.north_east) && (@south_west === box.south_west)
    end
    
    def to_s
      "(#{@north_east.latitude}, #{@north_east.longitude}, #{@south_west.latitude}, #{@south_west.longitude})"
    end
    
  end
end


