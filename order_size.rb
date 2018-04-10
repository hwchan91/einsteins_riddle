require 'pry'
require 'ostruct'

class Node
  attr_accessor :name, :greater_than, :less_than, :less_than_symbol, :greater_than_symbol

  def initialize(opt, comparison = OpenStruct.new(lesser: "<", greater: ">"))
    @name = opt[:name]
    @greater_than = []
    @less_than = []
    @less_than_symbol = comparison.lesser
    @greater_than_symbol = comparison.greater
  end

  def relationship(symbol, is_front)
    if symbol == less_than_symbol && is_front || symbol == greater_than_symbol && !is_front
      @less_than
    else
      @greater_than
    end
  end

  def inferred_comparison(comparison_direction)
    nodes = self.send(comparison_direction).dup
    nodes.each do |node|
      nodes += node.send("inferred_#{comparison_direction}")
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

  def unflattened_trails(comparison_direction, existing_trail = [])
    return existing_trail if send(comparison_direction).empty?
    send(comparison_direction).map do |node|
      new_trail = existing_trail.clone
      new_trail << node
      node.unflattened_trails(comparison_direction, new_trail.clone)
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


class Sequence
  attr_accessor :nodes

  def initialize
    @nodes = {}
  end

  def parse(statement)
    symbol = statement.split("").find{|i| ["<", ">"].include? i }
    node_names = statement.split(symbol)
    found_nodes = node_names.map {|node_name| find_or_create_node(node_name) }

    #check_if_valid (i.e. not: A<B, B<C, C<A)

    found_nodes.each_with_index do |node, index|
      is_front = index == 0
      node.relationship(symbol, is_front) << other_node(found_nodes, is_front)
    end
  end

  def other_node(found_nodes, is_front)
    is_front ? found_nodes.last : found_nodes.first
  end

  def find_or_create_node(node_name)
    return @nodes[node_name] if @nodes[node_name]
    @nodes[node_name] = Node.new(name: node_name)
  end

  def longest_path
    longest_path_length = 0
    nodes.each do |node|
      # node.inferred_greater_than.count + node.inferred_greater_than.count
    end
  end
end

class GraphNode
  attr_accessor :name, :space

  def initialize(opt)
    @name = opt[:name]
    @space = 0
  end
end



# class Graph

# end
s = Sequence.new
s.parse('a<b')
s.parse('a<c')
s.parse('c<d')
s.parse('c<e')
a = s.nodes['a']
