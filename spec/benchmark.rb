require 'aws-sdk-s3' unless defined?(Aws::S3::Client)
require 'concurrent-ruby' unless defined?(Concurrent::FixedThreadPool)
require 'benchmark' unless defined?(Benchmark)

# Require the list_public_s3_objects.rb file
require_relative '../libraries/list_public_s3_objects'

# List all S3 buckets
s3 = Aws::S3::Client.new
buckets = s3.list_buckets.buckets.map(&:name)

# Get the bucket to benchmark from command line arguments or default to the first bucket
bucket_name = ARGV[0] || buckets.first

# Get the testing strategy from command line arguments or default to "lite"
strategy = ARGV[1] || 'lite'

# Define configurations for lite and deep strategies
configurations = {
  lite: {
    thread_pool_sizes: [10, 20],
    batch_sizes: [50, 100],
    max_retries_values: [1, 3],
    retry_delays: [0.1, 0.5]
  },
  deep: {
    thread_pool_sizes: [10, 20, 30, 40, 50],
    batch_sizes: [50, 100, 200, 300],
    max_retries_values: [1, 3, 5],
    retry_delays: [0.1, 0.5, 1.0]
  }
}

# Select configurations based on the strategy
selected_config = configurations[strategy.to_sym]

results = []

selected_config[:thread_pool_sizes].each do |thread_pool_size|
  selected_config[:batch_sizes].each do |batch_size|
    selected_config[:max_retries_values].each do |max_retries|
      selected_config[:retry_delays].each do |retry_delay|
        time =
          Benchmark.measure do
            # Call the list_public_s3_objects function without printing the results
            list_public_s3_objects(
              bucket_name,
              thread_pool_size: thread_pool_size,
              batch_size: batch_size,
              max_retries: max_retries,
              retry_delay: retry_delay
            )
          end
        results << {
          bucket: bucket_name,
          thread_pool_size: thread_pool_size,
          batch_size: batch_size,
          max_retries: max_retries,
          retry_delay: retry_delay,
          time: time.real
        }
      end
    end
  end
end

# Print results
results
  .sort_by { |result| result[:time] }
  .each do |result|
    puts "Bucket: #{result[:bucket]}, Thread Pool Size: #{result[:thread_pool_size]}, Batch Size: #{result[:batch_size]}, Max Retries: #{result[:max_retries]}, Retry Delay: #{result[:retry_delay]}, Time: #{result[:time]} seconds"
  end

# Find the best configuration
best_result = results.min_by { |result| result[:time] }

puts "\nBest Configuration:"
puts "Bucket: #{best_result[:bucket]}"
puts "Thread Pool Size: #{best_result[:thread_pool_size]}"
puts "Batch Size: #{best_result[:batch_size]}"
puts "Max Retries: #{best_result[:max_retries]}"
puts "Retry Delay: #{best_result[:retry_delay]}"
puts "Time: #{best_result[:time]} seconds"
