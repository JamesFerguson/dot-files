# c.f. http://pastie.org/179534

@reminders << %Q|
irb> bm(1000, Proc.new { 1 + 1 }) # benchmark 1000 iterations of the given Proc
|

def bm(repetitions, *blocks)
  require 'benchmark'

  Benchmark.bmbm {|b|
    blocks.each {|block|
      b.report {repetitions.times &block} 
    }  
  }
  nil
end