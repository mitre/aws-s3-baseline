require 'pp'
class AwsS3BucketObjects < Inspec.resource(1)
  name 'aws_s3_bucket_objects'
  desc 'List objects within an S3 Bucket'
  example "
    describe aws_s3_bucket_objects(bucket_name: 'test_bucket') do do
      its('keys') { should include '' }
    end
  "
  supports platform: 'aws'

  include AwsPluralResourceMixin
  attr_reader :bucket_name, :table

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:bucket_name],
      allowed_scalar_name: :bucket_name,
      allowed_scalar_type: String
    )
    if validated_params.empty? || !validated_params.key?(:bucket_name)
      raise ArgumentError, 'You must provide a bucket_name to aws_s3_bucket.'
    end

    validated_params
  end

  def fetch_from_api
    backend = BackendFactory.create(inspec_runner)
    @table = []
    pagination_opts = { bucket: bucket_name }
    catch_aws_errors do
      loop do
        api_result = backend.list_objects_v2(pagination_opts)
        @table += api_result.contents.map(&:to_h)
        break if api_result.next_continuation_token.nil?

        pagination_opts = { bucket: bucket_name, continuation_token: api_result.next_continuation_token }
      end
    end
    @table.each do |entry|
      entry[:public] = inspec.aws_s3_bucket_object(bucket_name: bucket_name, key: entry[:key]).public?
    end
  end

  # Underlying FilterTable implementation.
  filter = FilterTable.create
  filter.register_custom_matcher(:exists?) { |x| !x.entries.empty? }
  filter.register_column(:keys, field: :key)
  filter.register_column(:public_objects, field: :public)
  filter.install_filter_methods_on_resource(self, :table)

  def to_s
    "S3 Bucket #{@bucket_name} Objects"
  end

  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend self
      self.aws_client_class = Aws::S3::Client

      def list_objects_v2(pagination_opts)
        aws_service_client.list_objects_v2(pagination_opts)
      end
    end
  end
end
