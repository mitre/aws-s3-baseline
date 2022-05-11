module Aws::S3
  class Bucket
    def objects(options = {})
      batches = Enumerator.new do |y|
        options = options.merge(bucket: @name)
        resp = @client.list_objects_v2(options)
        resp.each_page do |page|
          batch = []
          pool = Concurrent::FixedThreadPool.new(16)
          mutex = Mutex.new
          page.data.contents.each do |c|
            # binding.pry
            pool.post do
              mutex.synchronize do
                batch << ObjectSummary.new(
                  bucket_name: @name,
                  key: c.key,
                  data: c,
                  client: @client
                )
              end
            end
          end
          pool.shutdown
          pool.wait_for_termination
          y.yield(batch)
        end
      end
      ObjectSummary::Collection.new(batches)
    end
  end
end

def has_public_objects(myBucket)
  Inspec::Log.debug "Processing Bucket: #{myBucket}"
  myPublicKeys = []
  s3 = Aws::S3::Resource.new
  pool = Concurrent::FixedThreadPool.new(56)
  mutex = Mutex.new
  s3.bucket(myBucket).objects.each do |object|
    Inspec::Log.debug "Examining Key: #{object.key}"
    pool.post do
      grants = object.acl.grants
      if grants.map { |x| x.grantee.type }.any? { |x| x =~ /Group/ } && grants.map do |x|
                                                                          x.grantee.uri
                                                                        end.any? { |x| x =~ /AllUsers|AuthenticatedUsers/ }
        mutex.synchronize do
          myPublicKeys << object.key
        end
      end
    end
  end
  pool.shutdown
  pool.wait_for_termination
  myPublicKeys
end
