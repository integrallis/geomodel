require 'spec_helper'

describe 'Geomodel::Types' do
  include Geomodel::Types
  
  describe 'Point' do
    it "can't be created with invalid latitude or longitude" do
      expect { Geomodel::Types::Point.new(95, 0) }.to raise_error
      expect { Geomodel::Types::Point.new(0, 185) }.to raise_error
    end
    
    it "can be created with valid latitude or longitude" do
      point = Geomodel::Types::Point.new(37, -122)
      
      expect(point.latitude).to eq(37)
      expect(point.longitude).to eq(-122)
    end
    
    it "can be compared to another point" do
      point_a = Geomodel::Types::Point.new(37, -122)
      point_b = Geomodel::Types::Point.new(37, -122)
      point_c = Geomodel::Types::Point.new(0, 0)
      
      expect(point_a).to eq(point_b)
      expect(point_a).to_not eq(point_c)
    end
    
    it "returns a suitable string representation" do
      point = Geomodel::Types::Point.new(37, -122)
      
      expect(point.to_s).to eq('(37, -122)')
    end
  end
  
  describe 'Box' do
    
    it "can't be created with invalid values" do
      expect { Geomodel::Types::Box.new(95, 0, 0, 0) }.to raise_error
    end
    
    it "can be created with valid values" do
      box = Geomodel::Types::Box.new(37, -122, 34, -125)
      
      expect(box.north).to eq(37)
      expect(box.south).to eq(34)
      expect(box.east).to eq(-122)
      expect(box.west).to eq(-125)
    end
    
    it "can be compared to another box" do
      box_a = Geomodel::Types::Box.new(37, -122, 34, -125)
      box_b = Geomodel::Types::Box.new(37, -122, 34, -125)
      
      expect(box_a).to eq(box_b)
    end
    
    it "can be created with north below south" do
      box = Geomodel::Types::Box.new(37, -122, 34, -125)
      
      expect { box.north = 32 }.to raise_error
      expect { box.south = 39 }.to raise_error
    end

  end
end