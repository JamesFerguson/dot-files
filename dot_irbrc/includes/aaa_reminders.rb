@reminders = [
  %Q{
Tab completion is available.
},
  %Q{
irb             # start a subsession, new stack all locals vars wiped
irb controller  # start a subsession with 'controller' as self
jobs            # list all subsessions
fg 0            # switch to subsession numbered 0
kill 1          # kill subsession numbered 1
},
  %Q{
irb> method(:poc)                             # inspect a method to see where it is defined
 => #<Method: Object(Wirble::Shortcuts)#poc>
irb> "abc".method(:upcase)                    # works inline of course
 => #<Method: String#upcase>
},
  %{
Re updating gems, when in doubt uninstall all and do a 'bundle install'. 'bundle update' or 'gem update' gave me weird results.
}
]