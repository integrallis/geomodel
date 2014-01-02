require 'spec_helper'
require 'hashie'

describe 'Geomodel' do
  
  before(:all) do
    class Entity
      attr_accessor :id, :location, :geocells
      
      def to_s
        self.id
      end
    end
    
    @flatiron = Entity.new
    @flatiron.id = 'Flatiron'
    @flatiron.location = Geomodel::Types::Point.new(40.7407092, -73.9894039)
    
    @outback = Entity.new
    @outback.id = 'Outback Steakhouse'
    @outback.location = Geomodel::Types::Point.new(40.7425610, -73.9922670)
    
    @museum_of_sex = Entity.new
    @museum_of_sex.id = 'Museum of Sex'
    @museum_of_sex.location = Geomodel::Types::Point.new(40.7440290, -73.9873500)
    
    @wolfgang = Entity.new
    @wolfgang.id = 'Wolfgang Steakhouse'
    @wolfgang.location = Geomodel::Types::Point.new(40.7466230, -73.9820620)
    
    @morgan = Entity.new
    @morgan.id ='Morgan Library'
    @morgan.location = Geomodel::Types::Point.new(40.7493672, -73.9817685)
    
    @places = [@flatiron, @outback, @museum_of_sex, @wolfgang, @morgan]
    
    @places.each do |place|
      place.geocells = Geomodel::GeoCell.generate_geocells(place.location)
    end
    
    @query_runner = lambda do |geocells|
      result = @places.reject do |o| 
        (o.geocells & geocells).length < 0
      end 

      result
    end
  end
  
  it "can calculate the geocells for a bounding box using the default cost function" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    bounding_box = Geomodel::GeoCell.compute_box(cell)
    geocells = Geomodel.geocells_for_bounding_box(bounding_box)
    
    expect(geocells.size).to be(2)
    expect(geocells).to include("8e6187fe6187f", "8e6187fe618d5")
  end
  
  it "can find nearby locations given a location (lat & lon) and a radius in meters" do
    results = Geomodel.proximity_fetch(@flatiron.location, @query_runner, 5, 500)
    places = results.map(&:first)
    distances = results.map(&:last)
    
    expect(results.size).to be(3)
    expect(places).to include(@flatiron, @outback, @museum_of_sex)
    expect(distances.max).to be <= 500
  end
  
  it "respects the max results parameters in a search by proximity" do
    results = Geomodel.proximity_fetch(@flatiron.location, @query_runner, 2, 500)
    places = results.map(&:first)
    distances = results.map(&:last)
    
    expect(results.size).to be(2)
    expect(places).to include(@flatiron, @outback)
    expect(distances.max).to be <= 500
  end
  
  it "respects the max results parameters in a search by proximity" do
    results = Geomodel.proximity_fetch(@flatiron.location, @query_runner, 5, 1000)
    places = results.map(&:first)
    distances = results.map(&:last)
    
    expect(results.size).to be(4)
    expect(places).to include(@flatiron, @outback, @museum_of_sex, @wolfgang)
    expect(distances.max).to be <= 1000
  end

end