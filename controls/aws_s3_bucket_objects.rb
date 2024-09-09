require_relative '../libraries/list_public_s3_objects'

control 'public-s3-bucket-objects' do
  impact 0.7
  title 'Ensure there are no publicly accessible S3 objects'
  desc 'Ensure there are no publicly accessible S3 objects'
  tag nist: %w[AC-6]
  tag severity: 'high'
  desc 'check',
       "Review your AWS console and note if any S3 bucket objects are set to 'Public'. If any objects are listed as 'Public', then this is a finding."
  desc 'fix',
       'Log into your AWS console and select the S3 buckets section. Select the buckets found in your review. For each object in the bucket select the permissions tab for the object and remove the Public Access permission.'

  exempt_buckets = input('exempt_buckets')
  test_buckets = input('test_buckets')
  single_bucket = input('single_bucket')
  list_public_s3_objects_params = input('list_public_s3_objects_params')

  only_if(
    'This control is Non Applicable since no S3 buckets were found.',
    impact: 0.0
  ) { !aws_s3_buckets.bucket_names.empty? }

  bucket_names =
    if single_bucket.present?
      [single_bucket.to_s]
    elsif test_buckets.present?
      test_buckets
    else
      aws_s3_buckets.bucket_names
    end

  bucket_names.sort.each do |bucket|
    if exempt_buckets.include?(bucket)
      describe "Bucket #{bucket}" do
        it "#{bucket} was not evaluated because it was exempted" do
          skip "#{bucket} was not evaluated because it was exempted"
        end
      end
    else
      public_objects =
        list_public_s3_objects(
          bucket,
          thread_pool_size: list_public_s3_objects_params['thread_pool_size'],
          batch_size: list_public_s3_objects_params['batch_size'],
          max_retries: list_public_s3_objects_params['max_retries'],
          retry_delay: list_public_s3_objects_params['retry_delay']
        )

      describe bucket do
        it 'should not have any public objects' do
          failure_message =
            if public_objects.count > 1
              "\t- #{public_objects.join("\n\t- ")} \n\tare public"
            elsif public_objects.count == 1
              "\t- #{public_objects.join("\n\t- ")} \n\tis public"
            end
          expect(public_objects).to be_empty, failure_message
        end
      end
    end
  end
end
