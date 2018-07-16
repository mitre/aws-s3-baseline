
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

  # keeping track of public objects in this array is the `public_objects` necessary for 
  # appropriate reporting otherwise, in the case when no public objects are found in the
  # buckets, the test would end without any reporting.

  if aws_s3_buckets.bucket_names.empty?
    impact 0.0
    desc "This control is Non Applicable since no S3 buckets were found."
  else

    public_objects = []

    aws_s3_buckets.bucket_names.each do |bucket|
      aws_s3_bucket_objects(bucket).keys.each do |key|

        if aws_s3_bucket_object(bucket_name: bucket, key: key).public?
            public_objects << key

          # following code will all the report public objects as fail.
          describe aws_s3_bucket_object(bucket_name: bucket, key: key) do
            it { should_not be_public } 
          end
        end
      end
    end

    describe "Number of public objects in S3 Buckets" do
      subject { public_objects.length }
      it { should be_zero }  
    end if public_objects.empty?
  end
end
