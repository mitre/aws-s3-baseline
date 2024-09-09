control 'public-s3-buckets' do
  impact 0.7
  title 'Ensure there are no publicly accessible S3 buckets'
  desc 'Ensure there are no publicly accessible S3 buckets'

  tag nist: ['AC-6']
  tag severity: 'high'

  desc 'check',
       "Review your AWS console and note if any S3 buckets are set to 'Public'. If any buckets are listed as 'Public', then this is a finding."
  desc 'fix',
       'Log into your AWS console and select the S3 buckets section. Select the buckets found in your review. Select the permissions tab for the bucket and remove the Public access permission.'

  exempt_buckets = input('exempt_buckets')
  test_buckets = input('test_buckets')
  single_bucket = input('single_bucket')

  only_if(
    'This control is Non Applicable since no S3 buckets were found.',
    impact: 0.0
  ) { !aws_s3_buckets.bucket_names.empty? }

  bucket_names = if single_bucket.present?
                   [single_bucket.to_s]
                 elsif test_buckets.present?
                   test_buckets
                 else
                   aws_s3_buckets.bucket_names
                 end

  bucket_names.sort.each do |bucket|
    if exempt_buckets.include?(bucket)
      describe "Bucket #{bucket}" do
        it 'should be exempted from evaluation' do
          skip "Bucket #{bucket} was not evaluated because it was exempted"
        end
      end
    else
      describe bucket do
        subject { aws_s3_bucket(bucket) }
        it 'should not be publicly accessible' do
          expect(subject).not_to be_public, "\tand is configured to be public."
        end
      end
    end
  end
end
