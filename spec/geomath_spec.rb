require 'spec_helper'
require 'hashie'

describe 'Geomodel::Math' do
  
  it 'can compute the distance between two points' do
    [ # lat a, lon a, lat b, lon b, distance
      [ 37,     -122,   42,     -75,      4024365   ],
      [ 36.12,  -86.67, 33.94,  -118.40,  2889677.0 ],
    ].each do |lat_a, lon_a, lat_b, lon_b, expected_dist|
      # known distances using GLatLng from the Maps API
      point_a = Hashie::Mash.new
      point_a.latitude = lat_a
      point_a.longitude = lon_a
    
      point_b = Hashie::Mash.new
      point_b.latitude = lat_b
      point_b.longitude = lon_b    
    
      half_of_a_percent = expected_dist / 200
    
      calc_dist = Geomodel::Math.distance(point_a, point_b)

      expect(calc_dist).to be_within(half_of_a_percent).of(expected_dist)
    end
  end
  
  # Test location that can cause math domain error (due to rounding) unless
  # the distance function clamps the spherical law of cosines value between
  # -1.0 and 1.0.  
  it 'can compute the distance correctly for in spite of rounding errors' do
    point_a = Hashie::Mash.new
    point_a.latitude = 47.291288
    point_a.longitude = 8.56613
    
    point_b = Hashie::Mash.new
    point_b.latitude = 47.291288
    point_b.longitude = 8.56613
    
    calc_dist = Geomodel::Math.distance(point_a, point_b)    
    expected_dist = 0.0
  
    expect(calc_dist).to eq(expected_dist)
  end
  
  # TODO: implement this test
  
  # 
  # @Test
  # public void testInterpolationForEdgeCase() {
  #   
  #   assertTrue(GeocellUtils.interpolationCount("8e6f727a6b0dd", "8e1d5c3ce9aff") > 0);
  # }

end