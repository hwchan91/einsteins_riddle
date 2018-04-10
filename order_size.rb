require 'pry'
require 'ostruct'

# if for a comparasion, e.g. A & B, both/either nodes' unit is intially not known, and thus A & B belong to a sequence; when both nodes' become known, their sequence can be inferred from the unit, and thus teach other's node in their respective Sequence objects can be removed (for performance)
class Sequence
  attr_accessor :name, :greater_than, :less_than

   # e.g. in a horizontal order arranged from left to right; 'is left of' represents :lesser, 'is right of' represents :greater
  def initialize(opt = {})
    @name         = opt[:name]
    @greater_than = []
    @less_than    = []
  end

  def inferred_comparison(comparison_direction)
    nodes = self.send(comparison_direction).dup
    nodes.each do |node|
      nodes += node.find_sequence(self.name).send("inferred_#{comparison_direction}")
    end
    nodes
  end

  def inferred_greater_than
    inferred_comparison("greater_than")
  end

  def inferred_less_than
    inferred_comparison("less_than")
  end

  def inferred_greater_than_names
    inferred_greater_than.map(&:name)
  end

  def inferred_less_than_names
    inferred_less_than.map(&:name)
  end

  #broken
  def unflattened_trails(comparison_direction, existing_trail = [])
    return existing_trail if send(comparison_direction).empty?
    send(comparison_direction).map do |node|
      new_trail = existing_trail.clone
      new_trail << node
      node.find_sequence(self.name).unflattened_trails(comparison_direction, new_trail.clone)
    end
  end

  def get_flattened(unflattened_trails)
    flattened_trails = []
    unflattened_trails.each do |trail|
      if !trail.first.is_a? Array
        flattened_trails << trail
      else
        flattened_trails += trail
      end
    end

    return flattened_trails if flattened_trails.all?{|trail| trail.first.is_a? Node }
    get_flattened(flattened_trails)
  end

  def get_trails_less_than
    get_flattened(unflattened_trails("less_than"))
  end

  def get_trails_less_than_names
    get_trails_less_than.map{|trail| trail.map(&:name)}
  end

  def get_trails_greater_than
    get_flattened(unflattened_trails("greater_than"))
  end

  def get_trails_greater_than_names
    get_trails_greater_than.map{|trail| trail.map(&:name)}
  end
end

#can ignore this for now
class Unit
  attr_accessor :belongs_to_attribute, :name, :convertable_units

  def initialize(opt = {})
    @belongs_to_attribute = opt[:attribute]
    @name = opt[:unit] # eg. g
    @convertable_units = {} # eg. lb, Kg
  end
end

# attributes should be the MOST BASIC unit possible, e.g. to represent color, instead of coding rgby into the same attribute, it should be 4 different attributes; when the actual color is queried, the 4 attributes are then combined to return its original color
class Attribute
  attr_accessor :name, :units, :sequence

  def initialize(opt = {})
    @name = opt[:name] # the quality that it measures, e.g. 'cold-hot', 'left-right', 'numerical: small-large'
    #contains units (that can convert between each other) & (a single?) sequence
    @units = []
    @sequence = Sequence.new(name: name)
  end
end


class Node
  attr_accessor :name, :attributes

  def initialize(opt = {})
    @name = opt[:name]
    @attributes = []
  end

  # TO DO: need to skip adding again if the relationship already exists
  def add_comparison(attribute_name:, relationship:, other_node:)
    sequence = find_sequence(attribute_name)
    sequence.send(relationship) << other_node # relationship: "less_than" OR "greater_than"
  end

  def find_or_add_attribute(attribute_name)
    attribute = attributes.find{|a| a.name == attribute_name}
    return attribute if attribute

    new_attribute = Attribute.new(name: attribute_name)
    @attributes << new_attribute
    new_attribute
  end

  def find_sequence(attribute_name)
    attribute = find_or_add_attribute(attribute_name)
    sequence = attribute.sequence
  end
end

class BipolarComparison
  attr_accessor :name, :lesser, :greater

  def initialize(opt = {})
    @name = opt[:name]
    @lesser = opt[:lesser]
    @greater = opt[:greater]
  end

  def self.all
    ObjectSpace.each_object(self).to_a
  end

  def self.count
    all.length
  end

  def self.identify(symbol)
    self.all.find{|c| [c.lesser, c.greater].include? symbol }
  end

  def in_words(symbol, is_front)
    if symbol == lesser && is_front || symbol == greater && !is_front
      'less_than'
    else
      'greater_than'
    end
  end
end

class Field
  attr_accessor :nodes

  def initialize
    @nodes = {}
  end

  def parse(statement)
    symbols = statement.split(" ")
    comparison = nil
    comparison_symbol = symbols.find{ |symbol| comparison = BipolarComparison.identify(symbol) }
    found_nodes = node_names(symbols, comparison_symbol).map {|node_name| find_or_create_node(node_name) }

    #check_if_valid (i.e. not: A<B, B<C, C<A)

    found_nodes.each_with_index do |node, index|
      is_front = index == 0
      node.add_comparison(attribute_name: comparison.name, relationship: comparison.in_words(comparison_symbol, is_front), other_node: other_node(found_nodes, is_front))
    end
  end

  # get the names immediately before and immediately after the comparison symbol
  def node_names(symbols, comparison_symbol)
    index = symbols.index(comparison_symbol)
    [symbols[index-1], symbols[index +1] ]
  end

  def other_node(found_nodes, is_front)
    is_front ? found_nodes.last : found_nodes.first
  end

  def find_or_create_node(node_name)
    return @nodes[node_name] if @nodes[node_name]
    @nodes[node_name] = Node.new(name: node_name)
  end
end


# predefine all comparisons that are used
BipolarComparison.new(name: "numerical_value", lesser: "<", greater: ">")

s = Field.new
s.parse('a < b')
s.parse('a < c')
s.parse('c < d')
s.parse('c < e')
s.parse('e < f')
s.parse('e < g')
s.parse('e < h')
s.parse('b > i')
s.parse('i < j')
a = s.nodes['a']
a.attributes.find{|a| a.name == 'numerical_value'}.sequence.get_trails_less_than_names
