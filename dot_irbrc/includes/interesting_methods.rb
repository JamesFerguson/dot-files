# monkey patch Object to have a method that pretty prints a list of relevent methods on any child
# cf http://stackoverflow.com/questions/123494/whats-your-favourite-irb-trick

@reminders << %Q{
irb> "abc".interesting_methods
  %                            count                        first                        next                         start_with?                  
  *                            crypt                        grep                         next!                        strip                        
  +                            cycle                        group_by                     none?                        strip!                       
...
}

def colputs(array)
  def num_columns; 5; end
  def col_width; 25; end
  def force_length(x)
    x = x.to_s
    max_length = col_width+2
    if x.length > max_length
      x = x[0..max_length-4] + '...'
    end
    x += (' '*max_length)
    x[0..max_length-1]
  end
  def get_element(array, i) # displays in column order instead of row order
    num_rows = (array.length/num_columns)+1
    col = i % num_columns
    row = i / num_columns
    array[col*num_rows+row]
  end
  for i in (0..array.length)
    print force_length(get_element(array, i))
    print "  "
    puts if (i % num_columns) == (num_columns-1)
  end
  nil
end

class Object
  # Return only the methods not present on basic objects
  def interesting_methods
    colputs (self.methods - Object.new.methods).sort
  end
end