require_relative '../libraries/concurrent_s3'

control 'Public_S3_Objects' do
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

  if aws_s3_buckets.bucket_names.empty?
    impact 0.0
    desc 'This control is Non Applicable since no S3 buckets were found.'

    describe 'This control is Non Applicable since no S3 buckets were found.' do
      skip 'This control is Non Applicable since no S3 buckets were found.'
    end
  elsif input('single_bucket').present?
    public_objects = has_public_objects(input('single_bucket').to_s)
    describe input('single_bucket').to_s do
      it 'should not have any public objects' do
        failure_message = public_objects.count > 1 ? "#{public_objects.join(', ')} are public" : "#{public_objects.join(', ')} is public"
        expect(public_objects).to be_empty, failure_message
      end
    end
  else
    aws_s3_buckets.bucket_names.each do |bucket|
      next if exception_bucket_list.include?(bucket)

      public_objects_multi = has_public_objects(bucket.to_s)
      describe bucket.to_s do
        it 'should not have any public objects' do
          failure_message = "#{public_objects_multi.join(', ')} is public"
          expect(public_objects_multi).to be_empty, failure_message
        end
      end
    end
  end
end
