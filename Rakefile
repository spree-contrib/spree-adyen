require 'spree/testing_support/common_rake'

task :default => [:spec]

desc 'Generates a dummy app for testing'
task :test_app do
  ENV['LIB_NAME'] = 'spree-adyen'
  Rake::Task['common:test_app'].invoke
end
