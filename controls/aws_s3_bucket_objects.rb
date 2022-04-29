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

  if aws_s3_buckets.bucket_names.empty?
    impact 0.0
    desc 'This control is Non Applicable since no S3 buckets were found.'

    describe 'This control is Non Applicable since no S3 buckets were found.' do
      skip 'This control is Non Applicable since no S3 buckets were found.'
    end
  elsif !input('single_bucket').to_s.empty?
    my_items = aws_s3_bucket_objects(bucket_name: input('single_bucket')).contents_keys
    describe "#{input('single_bucket')} object" do
      my_items.each do |key|
        describe key.to_s do
          subject { aws_s3_bucket_object(bucket_name: input('single_bucket'), key: key) }
          it { should_not be_public }
        end
      end
    end
  else
    aws_s3_buckets.bucket_names.each do |bucket|
      next if exception_bucket_list.include?(bucket)

      my_items = aws_s3_bucket_objects(bucket_name: bucket).contents_keys
      describe "#{bucket} object" do
        my_items.each do |key|
          describe key.to_s do
            subject { aws_s3_bucket_object(bucket_name: bucket, key: key) }
            it { should_not be_public }
          end
        end
      end
    end
  end
end
