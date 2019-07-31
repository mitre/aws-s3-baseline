control 's3-buckets-no-public-access' do
  impact 0.7
  title 'Ensure there are no publicly accessible S3 buckets'
  desc 'Ensure there are no publicly accessible S3 buckets'

  tag "nist": ['AC-6', 'Rev_4']
  tag "severity": 'high'

  tag "check": "Review your AWS console and note if any S3 buckets are set to
                'Public'. If any buckets are listed as 'Public', then this is
                a finding."

  tag "fix": "Log into your AWS console and select the S3 buckets section. Select
              the buckets found in your review. Select the permisssions tab for
              the bucket and remove the Public access permission."

  exception_bucket_list = attribute('exception_bucket_list')

  aws_s3_buckets.bucket_names.each do |bucket|
    next if exception_bucket_list.include?(bucket)

    describe aws_s3_bucket(bucket) do
      it { should_not be_public }
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
