if(defined?(ActiveRecord))
  db_deets = ActiveRecord::Base.connection.instance_variable_get(:@config)

  puts "\nTrue DB in use: #{db_deets[:username]}:#{db_deets[:database]}@#{db_deets[:host].try(:upcase)} via #{db_deets[:adapter]}\n\n"
end
