if ENV['TEST_TYPE'] == 'ORIGINAL' # The original
  puts "Running original tests"
  require_relative 'db_test'
  require_relative 'player_test'
  require_relative 'predicates_test'
  require_relative 'match_test'
  require_relative 'utils_test'
  require_relative 'speech_test'
  require_relative 'move_test'
  require_relative 'look_test'
  require_relative 'create_test'
  require_relative 'set_test'
  require_relative 'rob_test'
  require_relative 'wiz_test'
  require_relative 'stringutil_test'
  require_relative 'game_test'
  require_relative 'regression'
  require_relative 'help_test'
elsif ENV['TEST_TYPE'] == 'CONVERTED'
  puts "Running converted tests"
  require_relative 'db_test'
  require_relative 'player_test'
  require_relative 'predicates_test'
  require_relative 'match_test'
  require_relative 'utils_test'
  require_relative 'speech_test'
  require_relative 'move_test'
  #require_relative 'look_test'
  #require_relative 'create_test'
  require_relative 'set_test'
  require_relative 'rob_test'
  require_relative 'wiz_test'
  #require_relative 'stringutil_test'
  #require_relative 'game_test'
  #require_relative 'regression' # Enable this last
  #require_relative 'help_test'
else
  throw "Unknown test type!"
end
