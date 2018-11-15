
control "s3-objects-no-public-access" do
  impact 0.7
  title "Ensure there are no publicly accessible S3 objects"
  desc "Ensure there are no publicly accessible S3 objects"
  tag "nist": ["AC-6", "Rev_4"]
  tag "severity": "high"

  tag "check": "Review your AWS console and note if any S3 bucket objects are set to
        'Public'. If any objects are listed as 'Public', then this is
        a finding."

  tag "fix": "Log into your AWS console and select the S3 buckets section. Select
        the buckets found in your review. For each object in the bucket
        select the permissions tab for the object and remove
        the Public Access permission."


  if aws_s3_buckets.bucket_names.empty?
    impact 0.0
    desc "This control is Non Applicable since no S3 buckets were found."
  else
    aws_s3_buckets.bucket_names.each do |bucket|
      describe "Public objects in Bucket: #{bucket}" do
        subject { aws_s3_bucket_objects(bucket).where{ public }.keys }
        it { should cmp [] } 
      end
    end
  end
end


