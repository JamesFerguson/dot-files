if(defined?(ActiveRecord))
  db_deets = ActiveRecord::Base.connection.instance_variable_get(:@config)

  puts "\n\nTrue DB in use: #{db_deets[:username]}:#{db_deets[:database]}@#{db_deets[:host]} via #{db_deets[:adapter]}"
end
