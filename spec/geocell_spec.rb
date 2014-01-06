require 'spec_helper'

describe 'Geomodel::GeoCell' do

  it "can compute a valid geocell" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    
    expect(cell.size).to eq(14)
    expect(Geomodel::GeoCell.is_valid(cell)).to be_true
    expect(Geomodel::GeoCell.contains_point(cell, Geomodel::Types::Point.new(37, -122)))
  end
  
  it "can determined if a geocell is invalid" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(0, 0), 0)
    
    expect(cell.size).to eq(0)
    expect(Geomodel::GeoCell.is_valid(cell)).to be_false
  end
  
  it "contains a lower resolution cell containing the same point as a prefix" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    lowres_cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 8)
    
    expect(cell.start_with?(lowres_cell)).to be_true
    expect(Geomodel::GeoCell.contains_point(lowres_cell, Geomodel::Types::Point.new(37, -122)))
  end
  
  it "can compute a box" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    box = Geomodel::GeoCell.compute_box(cell)
    
    expect(box.south).to be <= 37 
    expect(box.north).to be >= 37
    expect(box.west).to be <= -122
    expect(box.east).to be >= -122
  end
  
  it "can determine adjacency using bounding boxes" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    box = Geomodel::GeoCell.compute_box(cell)
    
    adjacent_south = Geomodel::GeoCell.adjacent(cell, [0, 1])
    adjacent_north = Geomodel::GeoCell.adjacent(cell, [0, -1])
    adjacent_west = Geomodel::GeoCell.adjacent(cell, [1, 0])
    adjacent_east = Geomodel::GeoCell.adjacent(cell, [-1, 0])
    
    adjacent_south_box = Geomodel::GeoCell.compute_box(adjacent_south)
    adjacent_north_box = Geomodel::GeoCell.compute_box(adjacent_north)
    adjacent_west_box = Geomodel::GeoCell.compute_box(adjacent_west)
    adjacent_east_box = Geomodel::GeoCell.compute_box(adjacent_east)
    
    all_adjacents = Geomodel::GeoCell.all_adjacents(cell)
    
    expect(adjacent_south_box.north).to be_within(0.00001).of(box.north)
    expect(adjacent_north_box.south).to be_within(0.00001).of(box.south)
    expect(adjacent_west_box.east).to be_within(0.00001).of(box.east)
    expect(adjacent_east_box.west).to be_within(0.00001).of(box.west)
    expect(all_adjacents.size).to eq(8)
  end
  
  it "can determine adjacency left and bottom of parent cell" do
    cells = {
            "8e6187fe6187fa" => ["8e6187fe618d45", "8e6187fe618d50", "8e6187fe618d51", "8e6187fe6187fb", "8e6187fe6187f9", "8e6187fe6187f8", "8e6187fe6187ed", "8e6187fe6187ef"],
            "8e6187fe618d45" => ["8e6187fe618d46", "8e6187fe618d47", "8e6187fe618d52", "8e6187fe618d50", "8e6187fe6187fa", "8e6187fe6187ef", "8e6187fe6187ee", "8e6187fe618d44"]
            }
    cells.each do |cell, adjacents|
      expect(Geomodel::GeoCell.all_adjacents(cell)).to eq(adjacents)
    end
  end
  
  it "cam calculate the immediate children of a given geocell" do
    expect(Geomodel::GeoCell.children("8e6187fe6187f")).
    to eq(
    %w(8e6187fe6187f0 8e6187fe6187f1 8e6187fe6187f2 8e6187fe6187f3 
      8e6187fe6187f4 8e6187fe6187f5 8e6187fe6187f6 8e6187fe6187f7 
      8e6187fe6187f8 8e6187fe6187f9 8e6187fe6187fa 8e6187fe6187fb 
      8e6187fe6187fc 8e6187fe6187fd 8e6187fe6187fe 8e6187fe6187ff)
    )
  end
  
  it "can determine collinearity" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    
    adjacent_south = Geomodel::GeoCell.adjacent(cell, [0, 1])
    adjacent_west = Geomodel::GeoCell.adjacent(cell, [1, 0])

    expect(Geomodel::GeoCell.collinear(cell, adjacent_south, true)).to be_true
    expect(Geomodel::GeoCell.collinear(cell, adjacent_south, false)).to be_false
    expect(Geomodel::GeoCell.collinear(cell, adjacent_west, false)).to be_true
    expect(Geomodel::GeoCell.collinear(cell, adjacent_west, true)).to be_false
  end

  it "can be interpolated" do
    cell = Geomodel::GeoCell.compute(Geomodel::Types::Point.new(37, -122), 14)
    
    sw_adjacent = Geomodel::GeoCell.adjacent(cell, [-1, -1])
    sw_adjacent2 = Geomodel::GeoCell.adjacent(sw_adjacent, [-1, -1])
    
    # interpolate between a cell and south-west adjacent, should return
    # 4 total cells
    expect(Geomodel::GeoCell.interpolate(cell, sw_adjacent).size).to eq(4)
    expect(Geomodel::GeoCell.interpolation_count(cell, sw_adjacent)).to eq(4)

    # interpolate between a cell and the cell SW-adjacent twice over,
    # should return 9 total cells
    expect(Geomodel::GeoCell.interpolate(cell, sw_adjacent2).size).to eq(9)
    expect(Geomodel::GeoCell.interpolation_count(cell, sw_adjacent2)).to eq(9)    
  end
  
  it "can create the best bounding box across a major cell boundary" do
    bbox = Geomodel::Types::Box.new(43.195111, -89.998193, 43.19302, -90.002356)
    geocells = Geomodel::GeoCell.best_bbox_search_cells(bbox, Geomodel::DEFAULT_COST_FUNCTION)
    
    expect(geocells.size).to be(16)
    expect(geocells).to include(
      "8ff77dfd4", "8ff77dfd5", "8ff77dfd6", "8ff77dfd7", "8ff77dfdc", "8ff77dfdd", 
      "8ff77dfde", "8ff77dfdf", "9aa228a80", "9aa228a81", "9aa228a82", "9aa228a83", 
      "9aa228a88", "9aa228a89", "9aa228a8a", "9aa228a8b"
    )
  end
  
  it "can create the best bounding box at the maximum resolution" do
    bbox = Geomodel::Types::Box.new(43.195110, -89.998193, 43.195110, -89.998193)
    geocells = Geomodel::GeoCell.best_bbox_search_cells(bbox, lambda { |num_cells, resolution|
      resolution <= Geomodel::GeoCell::MAX_GEOCELL_RESOLUTION ? 0 : Math.exp(10000)
    })
    
    expect(geocells.size).to be(1)
    expect(geocells).to include("9aa228a8b3b00")
  end
  
  it "can calculate that the shortest distance between a point and a geocell bounding boxfor the point is effectively zero" do
    point = Geomodel::Types::Point.new(40.7407092, -73.9894039)
    cell = "9ac7be064ea77"
    expect(Geomodel::GeoCell.point_distance(cell, point)).to be_within(0.2).of(0.0)
  end
  
  it "can calculate the shortest distance between a point outside a geocell and the geocell" do
    point = Geomodel::Types::Point.new(40.7425610, -73.9922670)
    cell = "9ac7be064ea77"
    expect(Geomodel::GeoCell.point_distance(cell, point)).to be_within(0.2).of(317.2)
  end
  
  it "can calculate the shortest distance between a point between north and south (but not between east and west) of a geocell bounding box" do
    point = Geomodel::Types::Point.new(40.740710, -74.025537)
    cell = "9ac7be064ea77"
    expect(Geomodel::GeoCell.point_distance(cell, point)).to be_within(0.2).of(3047.3)
  end
  
  it "can calculate the shortest distance between a point between east and west (but not between north and south) of a geocell bounding box" do
    point = Geomodel::Types::Point.new(40.740720, -73.989403)
    cell = "9ac7be064ea77"
    expect(Geomodel::GeoCell.point_distance(cell, point)).to be_within(0.2).of(0.99)
  end
  
  # TODO implement these tests!
  
  #   @Test
  # public void testBestBoxSearchOnAntimeridian() {
  #   float east = 64.576263f;
  #   float west = 87.076263f;
  #   float north = 76.043611f;
  #   float south = -54.505934f;
  #   Set<String> antimeridianSearch = new HashSet<String>(GeocellManager.bestBboxSearchCells(new BoundingBox(north,east,south,west), null));
  #   
  #   List<String> equivalentSearchPart1 = GeocellManager.bestBboxSearchCells(new BoundingBox(north,east,south,-180.0f), null);
  #   List<String> equivalentSearchPart2 = GeocellManager.bestBboxSearchCells(new BoundingBox(north,180.0f,south,west), null);
  #   Set<String> equivalentSearch = new HashSet<String>();
  #   equivalentSearch.addAll(equivalentSearchPart1);
  #   equivalentSearch.addAll(equivalentSearchPart2);
  #   
  #   assertEquals(equivalentSearch, antimeridianSearch);
  # }
  
  #   @Test
  # public void testBestBoxWithCustomCostFunction() {
  #   final int numCellsMax = 30;
  #   BoundingBox bb = new BoundingBox(38.912056, -118.40747, 35.263195, -123.88965);
  # 
  #   List<String> cells = GeocellManager.bestBboxSearchCells(bb, new CostFunction() {
  # 
  #   @Override
  # 
  #   public double defaultCostFunction(int numCells, int resolution)
  # 
  #   {
  #   // Here we ensure that we do not try to query more than 30 cells, the limit of a gae IN filter
  #   return numCells > numCellsMax ? Double.MAX_VALUE : 0;
  #   }
  # 
  #   });
  #   
  #   assertTrue(cells != null);
  #   assertTrue(cells.size() > 0);
  #   assertTrue(cells.size() <= numCellsMax);
  # }
  
end