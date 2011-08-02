# c.f. https://github.com/dadooda/ori

@reminders += [
  %Q{
irb> Array.ri # ri for a class
irb> [].ri # alternative
},
  %Q{
irb> Array.ri :sort # ri for a method
irb> [].ri :sort # alternative
},
  %Q{
irb> String.ri // # show a list of all ri-able methods
irb> String.ri /^to/ # show a list of methods matching regexp
irb> String.ri //, :access => "::" # specify an option on regexp, this is class methods only

# other options:
# :access => "#" - instance methods
# :own - own methods only
# :visibility => :private / [:public, :protected] # select for visibility
# :full_re => /\(Object\)::/ # apply additional re to absolute name
}
]

require 'ori'