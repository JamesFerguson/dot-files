# load a gem/lib into irb from the global gemset
#
# inspired by
#   https://gist.github.com/955611
#   https://github.com/aniero/dotfiles/blob/master/irbrc#L4-35
#
# IRB.gem('irbcp')
# IRB.gem('awesome_print', :lib => 'ap')
#
def IRB.gem(name, options = {})
  name = name.to_s
  lib = (options[:lib] || options['lib'] || name).to_s

  require(lib)
rescue LoadError => e
  candidates = []

  Gem.path.each do |path|
    glob = File.join(path, 'gems/*-[0-9].[0-9].[0-9]') 

    Dir.glob(glob) do |entry|
      basename = File.basename(entry)
      gemname, version = basename.split(/-/, 2)

      if gemname == name
        libdir = File.expand_path(File.join(entry, 'lib'))
        class << libdir; attr_accessor(:gemname);  attr_accessor(:version); end
        libdir.gemname = gemname
        libdir.version = version.scan(/\d+/).map{|digit| digit.to_i}
        candidates.push(libdir)
      end
    end
  end

  raise if candidates.empty?
  candidates.sort!{|a,b| a.version <=> b.version}
  libdir = candidates.last

  begin
    $LOAD_PATH.unshift(libdir)
    require(lib)
  ensure
    $LOAD_PATH.shift()
  end
end

require('rubygems') unless defined?(Gem)
