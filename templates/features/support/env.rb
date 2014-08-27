require 'leibniz'

Leibniz.configure do |config|
  # Sets the kitchen log level. See kitchen docs.
  # config.log_level = :info

  # Sets kitchen to redirect it's log output to a file instead of stdout.
  # config.log_to_file = false

  # Sets the vagrant vm memory
  # config.driver.memory = 512

  # Sets a cap on cpu execution time as a percent
  # config.driver.cpuexecutioncap = 100

end