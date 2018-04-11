require 'pry'
require 'ostruct'

# when making comparison return all associated nodes, by default, but should also have option to only return nodes included in a specific array, or scope

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
  attr_accessor :name, :attributes, :scope, :mother_node

  def initialize(opt = {})
    @name        = opt[:name]
    @attributes  = []
    @scope       = opt[:scope] || 'default'
    @mother_node = opt[:node]
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

  def self.all
    ObjectSpace.each_object(self).to_a
  end

  def self.count
    all.length
  end

  def self.find(name, scope = 'default')
    self.all.find{|n| n.name == name && n.scope == scope }
  end

  def find_attr(attr_name)
    attributes.find{|a| a.name == attr_name }
  end

  def find_seq(attr_name)
    find_attr(attr_name).sequence
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

  def in_words(symbol)
    symbol == lesser ? 'less_than' : 'greater_than'
  end

  def in_words_reversed(symbol)
    symbol == lesser ? 'greater_than' : 'less_than'
  end
end



# when parsing, should only select nodes that match on scope, when nodes are created, the scope is 'default' by default
def parse(statement)
  symbols = statement.split(" ")
  comparison = nil
  comparison_symbol = symbols.find{ |symbol| comparison = BipolarComparison.identify(symbol) }
  first_node, second_node = node_names(symbols, comparison_symbol).map {|node_name| find_or_create_node(node_name) }

  #check_if_valid (i.e. not: A<B, B<C, C<A)

  first_node.add_comparison(attribute_name: comparison.name, relationship: comparison.in_words(comparison_symbol), other_node: second_node)
  second_node.add_comparison(attribute_name: comparison.name, relationship: comparison.in_words_reversed(comparison_symbol), other_node: first_node)
end

# get the names immediately before and immediately after the comparison symbol
def node_names(symbols, comparison_symbol)
  index = symbols.index(comparison_symbol)
  [symbols[index-1], symbols[index +1] ]
end

def find_or_create_node(node_name, scope = 'default')
  found_node = Node.all.find{|n| n.scope == scope && n.name == node_name }
  return found_node if found_node
  Node.new(name: node_name, scope: scope)
end


# predefine all comparisons that are used
BipolarComparison.new(name: "numerical_value", lesser: "<", greater: ">")
BipolarComparison.new(name: "height", lesser: "is_shorter_than", greater: "is_taller_than")

parse('a < b')
parse('a < c')
parse('c < d')
parse('c < e')
parse('e < f')
parse('e < g')
parse('e < h')
parse('b > i')
parse('i < j')
a = Node.find('a')
a.find_seq('numerical_value').get_trails_less_than_names

# parse('a is_shorter_than b')
# parse('a is_shorter_than c')
# parse('c is_shorter_than d')
# parse('c is_shorter_than e')
# parse('e is_shorter_than f')
# parse('e is_shorter_than g')
# parse('e is_shorter_than h')
# parse('b is_taller_than i')
# parse('i is_shorter_than j')
# a = Node.find('a')
# a.find_seq('height').get_trails_less_than_names
