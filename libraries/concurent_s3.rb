def has_public_objects(myBucket)
    Inspec::Log.debug "Processing Bucket: #{myBucket}"
    myPublicKeys = []
    s3 = Aws::S3::Resource.new()
    pool = Concurrent::FixedThreadPool.new(56)
    mutex = Mutex.new
    s3.bucket(myBucket).objects.each do |object|
      Inspec::Log.debug "Examining Key: #{object.key}"
      pool.post do
        grants = object.acl.grants 
        if grants.map { |x| x.grantee.type }.any? { |x| x =~ %r{Group} }
          if grants.map { |x| x.grantee.uri }.any? { |x| x =~ %r{AllUsers|AuthenticatedUsers} }
            mutex.synchronize do
            myPublicKeys << object.key
            end
              end
        end
        end
    end  
    pool.shutdown
    pool.wait_for_termination
    myPublicKeys
  end