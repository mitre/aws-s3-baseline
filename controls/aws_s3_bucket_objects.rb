control 's3-objects-no-public-access' do
  impact 0.7
  title 'Ensure there are no publicly accessible S3 objects'
  desc 'Ensure there are no publicly accessible S3 objects'
  tag "nist": ['AC-6', 'Rev_4']
  tag "severity": 'high'

  tag "check": "Review your AWS console and note if any S3 bucket objects are set to
        'Public'. If any objects are listed as 'Public', then this is
        a finding."

  tag "fix": "Log into your AWS console and select the S3 buckets section. Select
        the buckets found in your review. For each object in the bucket
        select the permissions tab for the object and remove
        the Public Access permission."

  exception_bucket_list = attribute('exception_bucket_list')

  aws_s3_buckets.bucket_names.each do |bucket|
    next if exception_bucket_list.include?(bucket)

    describe "Public objects in Bucket: #{bucket}" do
      subject { aws_s3_bucket_objects(bucket).where { public }.keys }
      it { should cmp [] }
    end
  end

  if aws_s3_buckets.bucket_names.empty?
    impact 0.0
    desc 'This control is Non Applicable since no S3 buckets were found.'

    describe 'This control is Non Applicable since no S3 buckets were found.' do
      skip 'This control is Non Applicable since no S3 buckets were found.'
    end
  end
end
