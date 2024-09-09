# Rakefile

# Define a task to run benchmarks
namespace :benchmark do
  desc 'Run the benchmark script'
  task :run, %i[bucket_name strategy] do |_t, args|
    args.with_defaults(bucket_name: 'saf-site', strategy: 'lite')
    sh "ruby spec/benchmark.rb '#{args[:bucket_name]}' '#{args[:strategy]}'"
  end
end

desc "Run default benchmark with 'saf-site' bucket and 'lite' strategy"
task default: 'benchmark:run'

desc 'Alias for default task'
task test: :default
