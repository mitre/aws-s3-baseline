require 'aws-sdk-s3'
require 'concurrent-ruby'

def list_public_objects(bucket_name)
  public_objects = []
  continuation_token = nil

  # Determine the bucket's region
  s3 = Aws::S3::Client.new
  bucket_location =
    s3.get_bucket_location(bucket: bucket_name).location_constraint
  bucket_region = bucket_location.empty? ? 'us-east-1' : bucket_location

  # Create a new S3 client in the bucket's region
  s3 = Aws::S3::Client.new(region: bucket_region)

  loop do
    response =
      s3.list_objects_v2(
        bucket: bucket_name,
        continuation_token: continuation_token
      )
    futures =
      response.contents.map do |object|
        Concurrent::Future.execute do
          acl = s3.get_object_acl(bucket: bucket_name, key: object.key)
          if acl.grants.any? do |grant|
               grant.grantee.type == 'Group' &&
               (grant.grantee.uri =~ /AllUsers|AuthenticatedUsers/)
             end
            object.key
          end
        end
      end

    futures.each do |future|
      key = future.value
      public_objects << key if key
    end

    break unless response.is_truncated

    continuation_token = response.next_continuation_token
  rescue Aws::S3::Errors::PermanentRedirect => e
    # This block should not be reached if we correctly determine the bucket's region
    puts "PermanentRedirect error: #{e.message}"
    break
  end

  public_objects
end

# Example usage
bucket_name = 'saf-site'
public_objects = list_public_objects(bucket_name)
puts "Public objects in bucket '#{bucket_name}':"
puts public_objects
