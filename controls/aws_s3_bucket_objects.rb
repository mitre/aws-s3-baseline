require 'pry'
require 'pry-byebug'
require 'concurrent'
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
            #binding.pry
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

control 's3-objects-no-public-access' do
  impact 0.7
  title 'Ensure there are no publicly accessible S3 objects'
  desc 'Ensure there are no publicly accessible S3 objects'
  tag "nist": %w[AC-6]
  tag "severity": 'high'

  tag "check": "Review your AWS console and note if any S3 bucket objects are set to
        'Public'. If any objects are listed as 'Public', then this is
        a finding."

  tag "fix": "Log into your AWS console and select the S3 buckets section. Select
        the buckets found in your review. For each object in the bucket
        select the permissions tab for the object and remove
        the Public Access permission."

  exception_bucket_list = input('exception_bucket_list')

  def has_public_objects(myBucket)

    myPublicKeys = []
    s3 = Aws::S3::Resource.new()
    pool = Concurrent::FixedThreadPool.new(56)
    mutex = Mutex.new
    s3.bucket(myBucket).objects.each do |object|
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

  if aws_s3_buckets.bucket_names.empty?
    impact 0.0
    desc 'This control is Non Applicable since no S3 buckets were found.'

    describe 'This control is Non Applicable since no S3 buckets were found.' do
      skip 'This control is Non Applicable since no S3 buckets were found.'
    end
  elsif !input('single_bucket').to_s.empty?
    public_objects = has_public_objects(input('single_bucket').to_s)
    describe "This bucket #{input('single_bucket').to_s}" do
      it 'should not have Public Objects' do
        failure_message = "The following items are public: #{public_objects.join(', ')}"
        expect(public_objects).to be_empty, failure_message
      end
    end
  else
    aws_s3_buckets.bucket_names.each do |bucket|
      #next if exception_bucket_list.include?(bucket)
      public_objects = has_public_objects(bucket.to_s)
      binding.pry
      describe "This bucket #{bucket}" do
        it 'should not have Public Objects' do
          failure_message = "The following items are public: #{public_objects.join(', ')}"
          expect(public_objects).to be_empty, failure_message
        end
      end
    end
  end
end
