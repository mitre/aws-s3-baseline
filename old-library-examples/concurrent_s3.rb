# Conditionally require the concurrent library
require 'concurrent'

module Aws::S3
  class Bucket
    def objects(options = {})
      batches =
        Enumerator.new do |y|
          options = options.merge(bucket: @name)
          begin
            resp = @client.list_objects_v2(options)
            resp.each_page do |page|
              batch = []
              pool = Concurrent::FixedThreadPool.new(16)
              mutex = Mutex.new
              page.data.contents.each do |c|
                pool.post { process_object(c, batch, mutex) }
              end
              pool.shutdown
              pool.wait_for_termination
              y.yield(batch)
            end
          rescue Aws::S3::Errors::PermanentRedirect => e
            handle_bucket_error(e, @name)
          rescue StandardError => e
            handle_generic_bucket_error(e, @name)
          end
        end
      ObjectSummary::Collection.new(batches)
    end

    private

    def process_object(c, batch, mutex)
      mutex.synchronize do
        batch << ObjectSummary.new(
          bucket_name: @name,
          key: c.key,
          data: c,
          client: @client
        )
      end
    rescue Aws::S3::Errors::PermanentRedirect => e
      handle_object_error(e, c.key)
    rescue StandardError => e
      handle_generic_object_error(e, c.key)
    end

    def handle_bucket_error(e, bucket_name)
      Inspec::Log.warn "Permanent redirect for bucket #{bucket_name}: #{e.message}"
    end

    def handle_generic_bucket_error(e, bucket_name)
      Inspec::Log.warn "Error accessing bucket #{bucket_name}: #{e.message}"
      Inspec::Log.warn "Backtrace: #{e.backtrace.join("\n")}"
    end

    def handle_object_error(e, key)
      Inspec::Log.warn "Permanent redirect for object #{key}: #{e.message}"
      skip_resource "Skipping object #{key} due to permanent redirect: #{e.message}"
    end

    def handle_generic_object_error(e, key)
      Inspec::Log.warn "Error processing object #{key}: #{e.message}"
      Inspec::Log.warn "Backtrace: #{e.backtrace.join("\n")}"
      skip_resource "Skipping object #{key} due to error: #{e.message}"
    end
  end
end

def get_public_objects(myBucket)
  results = { public_keys: [], redirect_buckets: [] }
  s3 = Aws::S3::Resource.new
  pool = Concurrent::FixedThreadPool.new(56)
  mutex = Mutex.new

  begin
    bucket = s3.bucket(myBucket)
    object_count = bucket.objects.count

    Inspec::Log.debug "### Processing Bucket ### : #{myBucket} with #{object_count} objects" if Inspec::Log.level == :debug

    # Check if the bucket has no objects
    return results if object_count.zero?

    bucket.objects.each do |object|
      Inspec::Log.debug "    Examining Key: #{object.key}" if Inspec::Log.level == :debug
      pool.post do
        grants = object.acl.grants
        if grants.map { |x| x.grantee.type }.any? { |x| x =~ /Group/ } &&
           grants
           .map { |x| x.grantee.uri }
           .any? { |x| x =~ /AllUsers|AuthenticatedUsers/ }
          mutex.synchronize { results[:public_keys] << object.key }
        end
      rescue Aws::S3::Errors::PermanentRedirect => e
        Inspec::Log.warn "Permanent redirect for object #{object.key}: #{e.message}"
        mutex.synchronize do
          results[:redirect_buckets] << myBucket unless results[:redirect_buckets].include?(myBucket)
        end
      rescue StandardError => e
        Inspec::Log.warn "Error processing object #{object.key}: #{e.message}"
        Inspec::Log.warn "Backtrace: #{e.backtrace.join("\n")}"
      end
    end

    # Ensure all tasks are completed before shutting down the pool
    pool.shutdown
    pool.wait_for_termination
  rescue Aws::S3::Errors::PermanentRedirect => e
    Inspec::Log.warn "Permanent redirect for bucket #{myBucket}: #{e.message}"
    results[:redirect_buckets] << myBucket unless results[:redirect_buckets].include?(myBucket)
  rescue StandardError => e
    Inspec::Log.warn "Error accessing bucket #{myBucket}: #{e.message}"
    Inspec::Log.warn "Backtrace: #{e.backtrace.join("\n")}"
  ensure
    pool.shutdown if pool
  end

  results
end

def process_public_object(object, myPublicKeys, mutex)
  grants = object.acl.grants
  if grants.map { |x| x.grantee.type }.any? { |x| x =~ /Group/ } &&
     grants
     .map { |x| x.grantee.uri }
     .any? { |x| x =~ /AllUsers|AuthenticatedUsers/ }
    mutex.synchronize { myPublicKeys << object.key }
  end
rescue Aws::S3::Errors::PermanentRedirect => e
  handle_object_error(e, object.key)
rescue StandardError => e
  handle_generic_object_error(e, object.key)
end

def log_bucket_processing(bucket_name, object_count)
  Inspec::Log.debug "### Processing Bucket ### : #{bucket_name} with #{object_count} objects" if Inspec::Log.level == :debug
end

def log_object_examination(key)
  Inspec::Log.debug "    Examining Key: #{key}" if Inspec::Log.level == :debug
end

def handle_bucket_error(e, bucket_name)
  Inspec::Log.warn "Permanent redirect for bucket #{bucket_name}: #{e.message}"
  skip_resource "Skipping bucket #{bucket_name} due to permanent redirect: #{e.message}"
end

def handle_generic_bucket_error(e, bucket_name)
  Inspec::Log.warn "Error accessing bucket #{bucket_name}: #{e.message}"
  Inspec::Log.warn "Backtrace: #{e.backtrace.join("\n")}"
  skip_resource "Skipping bucket #{bucket_name} due to error: #{e.message}"
end

def handle_object_error(e, key)
  Inspec::Log.warn "Permanent redirect for object #{key}: #{e.message}"
  skip_resource "Skipping object #{key} due to permanent redirect: #{e.message}"
end

def handle_generic_object_error(e, key)
  Inspec::Log.warn "Error processing object #{key}: #{e.message}"
  Inspec::Log.warn "Backtrace: #{e.backtrace.join("\n")}"
  skip_resource "Skipping object #{key} due to error: #{e.message}"
end
