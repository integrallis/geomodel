# Geomodel

[![Build Status](https://secure.travis-ci.org/integrallis/geomodel.png?branch=master)](http://travis-ci.org/integrallis/geomodel) 
[![Gem Version](https://badge.fury.io/rb/geomodel.png)](http://badge.fury.io/rb/geomodel)
[![Dependency Status](https://gemnasium.com/integrallis/geomodel.png)](https://gemnasium.com/integrallis/geomodel) 
[![Code Climate](https://codeclimate.com/github/integrallis/geomodel.png)](https://codeclimate.com/github/integrallis/geomodel)
[![Coverage Status](https://coveralls.io/repos/integrallis/geomodel/badge.png?branch=master)](https://coveralls.io/r/integrallis/geomodel?branch=master)

Geomodel aims to provide a generalized solution for performing basic indexing 
and querying of geospatial data in non-relation environments. At the core, this 
solution utilizes geohash-like objects called geocells.

A geocell is a hexadecimal string that defines a two dimensional rectangular
region inside the [-90,90] x [-180,180] latitude/longitude space. A geocell's
'resolution' is its length. For most practical purposes, at high resolutions,
geocells can be treated as single points.

Much like geohashes (see http://en.wikipedia.org/wiki/Geohash), geocells are 
hierarchical, in that any prefix of a geocell is considered its ancestor, with
geocell[:-1] being geocell's immediate parent cell.

To calculate the rectangle of a given geocell string, first divide the
[-90,90] x [-180,180] latitude/longitude space evenly into a 4x4 grid like so:

<pre>
               +---+---+---+---+ (90, 180)
               | a | b | e | f |
               +---+---+---+---+
               | 8 | 9 | c | d |
               +---+---+---+---+
               | 2 | 3 | 6 | 7 |
               +---+---+---+---+
               | 0 | 1 | 4 | 5 |
    (-90,-180) +---+---+---+---+
</pre>

NOTE: The point (0, 0) is at the intersection of grid cells 3, 6, 9 and c. And,
for example, cell 7 should be the sub-rectangle from (-45, 90) to (0, 180).   

Calculate the sub-rectangle for the first character of the geocell string and
re-divide this sub-rectangle into another 4x4 grid. For example, if the geocell
string is '78a', we will re-divide the sub-rectangle like so:

<pre>
                 .                   .
                 .                   .
             . . +----+----+----+----+ (0, 180)
                 | 7a | 7b | 7e | 7f |
                 +----+----+----+----+
                 | 78 | 79 | 7c | 7d |
                 +----+----+----+----+
                 | 72 | 73 | 76 | 77 |
                 +----+----+----+----+
                 | 70 | 71 | 74 | 75 |
    . . (-45,90) +----+----+----+----+
                 .                   .
                 .                   .
</pre>

Continue to re-divide into sub-rectangles and 4x4 grids until the entire
geocell string has been exhausted. The final sub-rectangle is the rectangular
region for the geocell.

A geocell can be associated with a single geographic point and subsequently 
indexed and filtered by either conformance to a bounding box or by proximity 
(nearest-n) to a search center point.

# Approach

This Ruby implementation of GeoModel is based on the Python, Java and JavaScript implementations. 
It's implemented as class level methods contained within modules and a few datatype classes. So the 
'model' part isn't quite there and I don't really see a need for it. Since the library is meant to 
be use in Non-Relational/Non-ORM environmets, binding the functions/methods to a model does not make
much sense. 

The model part was mostly implemented in the other libraries to bind directly to Google App Engine.
The idea here is to make it backend/db independent and use callbacks to integrate with the backend.

# References

- http://code.google.com/p/javageomodel/
- http://code.google.com/p/geomodel/
- https://github.com/danieldkim/geomodel

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'geomodel'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install geomodel

## Usage

Currently, only single-point entities and two types of basic geospatial queries
on those entities are supported.

### Representing your Locations

You'll need a class to hold a geolocation. It assumes that an "entity" has a unique 
"id" (specific field can be configure), a latitude/longitude combination stored in 
a "location" field (a Geomodel::Types::Point) and a collection of "geocells".

```ruby
class Entity
  attr_accessor :id, :location, :geocells
  
  def to_s
    self.id
  end
end
```

An instance of one of these entities can be instantiated as shown next. Let's say we
wanted to create an entity for the Frank Lloyd Wright Iconic Desert Spire in Scottsdale, AZ
(http://livebetterinscottsdale.com/2012/02/things-to-see-in-scottsdale-az-the-frank-lloyd-wright-spire/):

```ruby
flw_spire = Entity.new
flw_spire.id = 'Flatiron'
flw_spire.location = Geomodel::Types::Point.new(33.633406, -111.916803)
flw_spire.geocells = Geomodel::GeoCell.generate_geocells(flw_spire.location)

puts flw_spire.geocells
# 8
# 8d
# 8da
# 8daa
# 8daab
# 8daab6
# 8daab66
# 8daab666
# 8daab6668
# 8daab66684
# 8daab66684e
# 8daab66684e4
# 8daab66684e4d
```

### Bounding Box Queries

```ruby
# compute a geocell for the location using a resolution of 14
cell = Geomodel::GeoCell.compute(flw_spire.location, 14)

# create a bounding box for the cell
bounding_box = Geomodel::GeoCell.compute_box(cell)

# get a list of geocells for the given bounding box
geocells = Geomodel.geocells_for_bounding_box(bounding_box)

# use the bounding box geocells to do a key lookup in your database assuming that there is
# a location_geocell 'column' and you can do an IN query like:
result_set = my_db.query('SELECT * WHERE location_geocells IN (?)', query_geocells)

# the results then can be filtered by whether they fall inside the bounding box using:
matches = Geomodel.filter_result_set_by_bounding_box(bounding_box, result_set)
```

### Proximity (nearest-n) Queries

Find nearby locations given a location (lat & lon) and a radius in meters:

```ruby

# a list of places (instance of Entity or object that responds to :id, :location, :geocells)
places = [place1, place2, place3, ...]

# a function that can query your database. It takes as a parameter an array of geocells (strings)
# that are used to filter the query (below is an in-memory implementation using the 'places' array
# as our datasource)
query_runner = lambda do |geocells|
  result = places.reject do |o| 
    (o.geocells & geocells).length < 0
  end 

  result
end

# query for a maximum of 20 results, 15 miles (~24140 meters) from the Frank Lloyd Wright Spire
# results are tuples (2 element arrays) with the matching entity and its distance from the location
results = Geomodel.proximity_fetch(flw_spire.location, query_runner, 20, 24140)

# extract the matching places
places = results.map(&:first)

# extract the distances
distances = results.map(&:last)

```

## Demo

A Rails 4 Demo application of using the GeoModel Library with Cassandra (http://cassandra.apache.org/) can be found at https://github.com/integrallis/geomodel-cassandra-demo and a live demo is deployed on Heroku at http://geomodel.herokuapp.com/

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License
