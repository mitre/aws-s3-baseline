##
# The above functions utilize multithreading with a thread pool to efficiently process objects in an
# AWS S3 bucket and identify public objects based on their ACL grants.
#
# Args:
#   myBucket: The code you provided defines methods to retrieve public objects from an AWS S3 bucket
# using multi-threading for improved performance. The `get_public_objects` method iterates over the
# objects in the specified S3 bucket, checks their ACL permissions, and collects the keys of objects
# that are publicly accessible.
#
# Returns:
#   The `get_public_objects` method returns an array of keys for objects in a specified S3 bucket that
# have public access permissions for all users or authenticated users.
require "concurrent"
require "aws-sdk-s3"

module Aws::S3
  class Bucket
    def objects(options = {})
      options = options.merge(bucket: @name)
      resp = @client.list_objects_v2(options)

      # Check if the response contains any objects
      return ObjectSummary::Collection.new([]) if resp.contents.empty?

      pool = Concurrent::FixedThreadPool.new(16)
      log_thread_pool_status(pool, "Initialized")

      batches =
        Enumerator.new do |y|
          resp.each_page do |page|
            batch = Concurrent::Array.new
            page.data.contents.each do |c|
              begin
                pool.post do
                  begin
                    batch << ObjectSummary.new(
                      bucket_name: @name,
                      key: c.key,
                      data: c,
                      client: @client
                    )
                  rescue Aws::S3::Errors::PermanentRedirect => e
                    # Handle endpoint redirection error
                    Inspec::Log.debug "Permanent redirect for object #{c.key}: #{e.message}"
                  rescue => e
                    # Handle or log other errors
                    Inspec::Log.debug "Error processing object #{c.key}: #{e.message}"
                    Inspec::Log.debug "Backtrace: #{e.backtrace.join("\n")}"
                  end
                end
              rescue Concurrent::RejectedExecutionError => e
                # Handle the rejected execution error
                Inspec::Log.debug "Task submission rejected for object #{c.key}: #{e.message}"
                log_thread_pool_status(pool, "RejectedExecutionError")
              end
            end
            pool.shutdown
            pool.wait_for_termination
            y.yield(batch)
          end
        end
      ObjectSummary::Collection.new(batches)
    ensure
      pool.shutdown if pool
    end

    private

    def log_thread_pool_status(pool, context)
      if Inspec::Log.level == :debug
        Inspec::Log.debug "Thread pool status (#{context}):"
        Inspec::Log.debug "  Pool size: #{pool.length}"
        Inspec::Log.debug "  Queue length: #{pool.queue_length}"
        Inspec::Log.debug "  Completed tasks: #{pool.completed_task_count}"
      end
    end
  end
end

def get_public_objects(myBucket)
  myPublicKeys = Concurrent::Array.new
  s3 = Aws::S3::Resource.new
  pool = Concurrent::FixedThreadPool.new(56)
  log_thread_pool_status(pool, "Initialized")
  debug_mode = Inspec::Log.level == :debug

  begin
    bucket = s3.bucket(myBucket)
    object_count = bucket.objects.count

    if debug_mode
      Inspec::Log.debug "### Processing Bucket ### : #{myBucket} with #{object_count} objects"
    end

    # Check if the bucket has no objects
    return myPublicKeys if object_count.zero?

    bucket.objects.each do |object|
      Inspec::Log.debug "    Examining Key: #{object.key}" if debug_mode
      begin
        pool.post do
          begin
            grants = object.acl.grants
            if grants.map { |x| x.grantee.type }.any? { |x| x =~ /Group/ } &&
                 grants
                   .map { |x| x.grantee.uri }
                   .any? { |x| x =~ /AllUsers|AuthenticatedUsers/ }
              myPublicKeys << object.key
            end
          rescue Aws::S3::Errors::AccessDenied => e
            # Handle access denied error
            Inspec::Log.debug "Access denied for object #{object.key}: #{e.message}"
          rescue Aws::S3::Errors::PermanentRedirect => e
            # Handle endpoint redirection error
            Inspec::Log.debug "Permanent redirect for object #{object.key}: #{e.message}"
          rescue => e
            # Handle or log other errors
            Inspec::Log.debug "Error processing object #{object.key}: #{e.message}"
            Inspec::Log.debug "Backtrace: #{e.backtrace.join("\n")}"
          end
        end
      rescue Concurrent::RejectedExecutionError => e
        # Handle the rejected execution error
        Inspec::Log.debug "Task submission rejected for object #{object.key}: #{e.message}"
        log_thread_pool_status(pool, "RejectedExecutionError")
      end
    end

    # Ensure all tasks are completed before shutting down the pool
    pool.shutdown
    pool.wait_for_termination
  rescue Aws::S3::Errors::PermanentRedirect => e
    # Handle endpoint redirection error for the bucket
    Inspec::Log.debug "Permanent redirect for bucket #{myBucket}: #{e.message}"
  rescue => e
    # Handle or log other errors
    Inspec::Log.debug "Error accessing bucket #{myBucket}: #{e.message}"
    Inspec::Log.debug "Backtrace: #{e.backtrace.join("\n")}"
  ensure
    pool.shutdown if pool
  end

  myPublicKeys
end

def log_thread_pool_status(pool, context)
  if Inspec::Log.level == :debug
    Inspec::Log.debug "Thread pool status (#{context}):"
    Inspec::Log.debug "  Pool size: #{pool.length}"
    Inspec::Log.debug "  Queue length: #{pool.queue_length}"
    Inspec::Log.debug "  Completed tasks: #{pool.completed_task_count}"
  end
end
