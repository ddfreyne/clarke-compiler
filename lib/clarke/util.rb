def log(msg)
  $stderr.puts "[#{Time.now.strftime('%H:%M:%S.%L')}] #{msg}"
end
