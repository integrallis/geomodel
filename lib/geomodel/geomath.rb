require 'geocoder'

module Geomodel::Math
  
  RADIUS = 6378135
  
  # Calculates the great circle distance between two points (law of cosines).
  # 
  # Args:
  #   start_point: A geotypes.Point or db.GeoPt indicating the first point.
  #   end_point_: A geotypes.Point or db.GeoPt indicating the second point.
  # 
  # Returns:
  #   The 2D great-circle distance between the two given points, in meters.
  #
  def self.distance(start_point, end_point)
    start_point_lat = Geocoder::Calculations.to_radians(start_point.latitude)
    start_point_lon = Geocoder::Calculations.to_radians(start_point.longitude)
    end_point_lat = Geocoder::Calculations.to_radians(end_point.latitude) 
    end_point_lon = Geocoder::Calculations.to_radians(end_point.longitude)
    # work out the internal value for the spherical law of cosines and clamp
    # it between -1.0 and 1.0 to avoid rounding errors
    sloc = (Math.sin(start_point_lat) * Math.sin(end_point_lat) +
            Math.cos(start_point_lat) * Math.cos(end_point_lat) * Math.cos(end_point_lon - start_point_lon))
    sloc = [[sloc, 1.0].min, -1.0].max
    RADIUS * Math.acos(sloc)
  end
end