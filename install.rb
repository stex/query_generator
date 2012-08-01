# Install hook code here

puts <<-EOS


  Installation Complete
  ------------------------

  You might want to run the initializers now which will create necessary migrations and
  javascript/stylesheet files.

  This can be done with
              script/generate query_generator all
  Alternatively, you can get all available options with
              script/generate query_generator
  to generate only certain files
EOS