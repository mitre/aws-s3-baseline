# Conditionally require the needed libraries unless they are already loaded
require "aws-sdk-s3" unless defined?(Aws::S3::Client)
require "concurrent-ruby" unless defined?(Concurrent::FixedThreadPool)

##
# Lists all publicly accessible objects in an S3 bucket.
#
# This method iterates through all objects in the specified S3 bucket and checks
# their access control lists (ACLs) to determine if they are publicly accessible.
# It uses a thread pool to process objects concurrently for improved performance.
#
# @param bucket_name [String] The name of the S3 bucket.
# @param thread_pool_size [Integer] The size of the thread pool for concurrent processing. Default is 50.
# @param batch_size [Integer] The number of objects to process in each batch. Default is 200.
# @param max_retries [Integer] The maximum number of retries for S3 requests. Default is 5.
# @param retry_delay [Float] The delay between retries in seconds. Default is 0.5.
# @param s3_client [Aws::S3::Client, nil] An optional S3 client. If not provided, a new client will be created.
# @return [Array<String>] A list of keys for publicly accessible objects.
#
# @example List public objects in a bucket
#   public_objects = list_public_s3_objects('my-bucket')
#   puts "Public objects: #{public_objects.join(', ')}"

def list_public_s3_objects(
  bucket_name,
  thread_pool_size: 20,
  batch_size: 100,
  max_retries: 1,
  retry_delay: 0.1,
  s3_client: nil
)
  public_objects = []
  continuation_token = nil

  # Use the provided S3 client or create a new one
  s3 = s3_client || Aws::S3::Client.new

  # Determine the bucket's region
  bucket_location =
    s3.get_bucket_location(bucket: bucket_name).location_constraint
  bucket_region = bucket_location.empty? ? "us-east-1" : bucket_location

  # Create a new S3 client in the bucket's region if not provided
  s3 = s3_client || Aws::S3::Client.new(region: bucket_region)

  # Create a thread pool for concurrent processing
  thread_pool = Concurrent::FixedThreadPool.new(thread_pool_size)

  loop do
    # List objects in the bucket with pagination support
    response =
      s3.list_objects_v2(
        bucket: bucket_name,
        continuation_token: continuation_token,
      )
    response
      .contents
      .each_slice(batch_size) do |object_batch|
      # Process each batch of objects concurrently
      futures =
        object_batch.map do |object|
          Concurrent::Future.execute(executor: thread_pool) do
            retries = 0
            begin
              # Get the ACL for each object
              acl = s3.get_object_acl(bucket: bucket_name, key: object.key)
              # Check if the object is publicly accessible
              if acl.grants.any? do |grant|
                grant.grantee.type == "Group" &&
                (grant.grantee.uri =~ /AllUsers|AuthenticatedUsers/)
              end
                object.key
              end
            rescue Aws::S3::Errors::ServiceError
              retries += 1
              if retries <= max_retries
                sleep(retry_delay)
                retry
              end
            end
          end
        end

      # Collect the results from the futures
      futures.each do |future|
        key = future.value
        public_objects << key if key
      end
    end

    # Check if there are more objects to list
    break unless response.is_truncated

    continuation_token = response.next_continuation_token
  rescue Aws::S3::Errors::PermanentRedirect
    # This block should not be reached if we correctly determine the bucket's region
    break
  end

  # Shutdown the thread pool and wait for termination
  thread_pool.shutdown
  thread_pool.wait_for_termination

  public_objects
end
