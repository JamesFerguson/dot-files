@reminders += [
  %Q{
irb> ri String # => prints ri documetnation for String class
},
  %Q{
irb> po "s" # => array of String instance methods - Object.methods sorted
},
  %Q{
irb> poc x # => list all constants in 'x', sorted
}
]

IRB.gem 'wirble'

@colors = {
  # delimiter colors
  :comma              => :nothing,
  :refers             => :light_gray,
  
  # container colors (hash and array)
  :open_hash          => :green,
  :close_hash         => :green,
  :open_array         => :green,
  :close_array        => :green,
  
  # object colors
  :open_object        => :light_red,
  :object_class       => :cyan,
  :object_addr_prefix => :light_purple,
  :object_line_prefix => :light_cyan,
  :close_object       => :light_red,
  
  # symbol colors
  :symbol             => :red,
  :symbol_prefix      => :red,
  
  # string colors
  :open_string        => :purple,
  :string             => :green,
  :close_string       => :purple,
  
  # misc colors
  :number             => :blue,
  :keyword            => :blue,
  :class              => :cyan,
  :range              => :blue,
}


Wirble.init(
  :init_colors => true,
  :colors => @colors
)
Wirble::Colorize.colors = @colors
