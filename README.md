# aws-s3-baseline

A micro-baseline is provided to check for insecure or public S3 buckets and bucket objects in your AWS environment. This [InSpec](https://github.com/chef/inspec) compliance profile verifies that you do not have any insecure or publicly accessible S3 buckets or bucket objects in your AWS environment in an automated way.

## Required Gems

This profile requires the following gems:

- `inspec` (v5 or higher)
- `inspec-bin` (v5 or higher)
- `aws-sdk-s3` (v2 or higher, v3 recommended)
- `concurrent-ruby` (v1.1.0 or higher)

Please **install these gems** in the Ruby environment that InSpec is using before executing the profile.

### Large Buckets and Profile Runtime

The `public-s3-bucket-objects` control - and its support library `list_public_s3_objects` - iterates through every object in each bucket in your AWS environment. The runtime will depend on the number of objects in your S3 buckets.

On average, the profile can process around ~1000 objects/sec.

If you have buckets with a large number of objects, we suggest scripting a loop and using the `single_bucket` input to parallelize the workload, or you can use the `test_buckets` input to provide an array of buckets to test.

## Profile Inputs

- `single_bucket`: The name of the single bucket you wish to scan. This input is useful for testing a specific bucket.
- `exempt_buckets`: A list of buckets that should be exempted from review. This input allows you to skip certain buckets from being tested.
- `test_buckets`: A list of buckets to test. This input allows you to specify multiple buckets to be tested.
- `list_public_s3_objects_params`: A hash of parameters for the `list_public_s3_objects` function. This input allows you to configure the following parameters:
  - `thread_pool_size`: The size of the thread pool for concurrent processing. Default is 50. Increasing this value can improve performance for buckets with a large number of objects by allowing more concurrent processing, but it may also increase the load on your system.
  - `batch_size`: The number of objects to process in each batch. Default is 200. Adjusting this value can affect the balance between memory usage and processing speed.
  - `max_retries`: The maximum number of retries for S3 requests. Default is 5. This can help handle transient errors but may increase the overall runtime if set too high.
  - `retry_delay`: The delay between retries in seconds. Default is 0.5. This can help handle transient errors by spacing out retry attempts.

### Performance Considerations

- **Threading and Concurrency**: The `thread_pool_size` parameter controls the number of concurrent threads used to process objects. Increasing this value can improve performance by allowing more objects to be processed simultaneously, but it may also increase the load on your system and potentially lead to throttling by AWS.
- **Batch Processing**: The `batch_size` parameter controls the number of objects processed in each batch. Larger batch sizes can reduce the number of API calls to AWS, but they may also increase memory usage.
- **Retries and Delays**: The `max_retries` and `retry_delay` parameters control how the function handles transient errors. Increasing the number of retries and the delay between retries can improve the robustness of the function but may also increase the overall runtime.

To see the processing in more detail, use the `-l debug` flag to get verbose output.

You can then load all your HDF JSON results into [Heimdall Lite](https://heimdall-lite.mitre.org) to easily review all your scan results from multiple runs by loading them in Heimdall.

## Getting Started

It is intended and recommended that InSpec and this profile be run from a **"runner"** host (such as a DevOps orchestration server, an administrative management system, or a developer's workstation/laptop) against the target remotely using **AWS CLI**.

**For the best security of the runner, always install the _latest version_ of InSpec and supporting Ruby language components on the runner.**

The latest versions and installation options are available on the [InSpec](http://inspec.io/) site.

This baseline also requires the AWS Command Line Interface (CLI), which is available on the [AWS CLI](https://aws.amazon.com/cli/) site.

### Getting MFA Aware AWS Access, Secret, and Session Tokens

You need to ensure that your AWS CLI environment has the correct system environment variables set with your AWS region, credentials, and session token to use the AWS CLI and InSpec resources in the AWS environment. InSpec supports the following standard AWS variables:

- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (optional) - required if MFA is enabled

### Notes on MFA

In any AWS MFA-enabled environment, you need to use `derived credentials` to use the CLI. Your default `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` will not satisfy the MFA Policies in AWS environments.

The AWS documentation is available [here](https://docs.aws.amazon.com/cli/latest/reference/sts/get-session-token.html).

The AWS profile documentation is available [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html).

A useful bash script for automating this is available [here](https://gist.github.com/dinvlad/d1bc0a45419abc277eb86f2d1ce70625).

To generate credentials using an AWS Profile, you will need to use the following AWS CLI commands:

a. `aws sts get-session-token --serial-number arn:aws:iam::<$YOUR-MFA-SERIAL> --token-code <$YOUR-CURRENT-MFA-TOKEN> --profile=<$YOUR-AWS-PROFILE>`

b. Then export the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` that were generated by the above command.

## Tailoring to Your Environment

The following inputs must be configured in an inputs ".yml" file for the profile to run correctly in your specific environment. More information about InSpec inputs can be found in the [InSpec Profile Documentation](https://www.inspec.io/docs/reference/profiles/).

```yaml
# List of buckets exempted from inspection.
exception_bucket_list:
    - bucket1
    - bucket2
    ...

# Test only one bucket
single_bucket: 'my-bucket'

# Test specific buckets
test_buckets:
    - bucket3
    - bucket4
    ...
```

# Usage

```bash
# Set required ENV variables as per your environment

$ export AWS_REGION=us-east-1
$ export AWS_ACCESS_KEY_ID=...
$ export AWS_SECRET_ACCESS_KEY=...
$ export AWS_SESSION_TOKEN=... # if MFA is enabled
```

## Installing the Needed Gems

### Plain Old Ruby Environment

- `gem install concurrent-ruby`

### Using a Chef or CINC Omnibus Installation

- `chef gem install concurrent-ruby`

## Running This Baseline Directly from GitHub

### Testing all your buckets except those defined in your `excluded buckets`

`inspec exec https://github.com/mitre/aws-s3-baseline/archive/master.tar.gz --target aws:// --input-file=your_inputs_file.yml --reporter=cli json:your_output_file.json`

### Testing a single bucket

`inspec exec https://github.com/mitre/aws-s3-baseline/archive/master.tar.gz --target aws:// --input single_bucket=your_bucket --reporter=cli json:your_output_file.json`

### Testing specific buckets

`inspec exec https://github.com/mitre/aws-s3-baseline/archive/master.tar.gz --target aws:// --input-file=your_inputs_file.yml --reporter=cli json:your_output_file.json`

### Different Run Options

[Full exec options](https://docs.chef.io/inspec/cli/#options-3)

## Running This Baseline from a Local Archive Copy

If your runner does not always have direct access to GitHub, use the following steps to create an archive bundle of this baseline and all its dependent tests:

(Git is required to clone the InSpec profile using the instructions below. Git can be downloaded from the [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) site.)

When the **"runner"** host uses this profile baseline for the first time, follow these steps:

### Create your Archive of the Profile

```bash
mkdir profiles
cd profiles
git clone https://github.com/mitre/aws-s3-baseline
inspec archive aws-s3-baseline
```

### Run your scan using the Archived Copy

`inspec exec <name of generated archive> --target aws:// --input-file=<path_to_your_inputs_file/name_of_your_inputs_file.yml> --reporter=cli json:<path_to_your_output_file/name_of_your_output_file.json>`

### Updating your Archived Copy

For every successive run, follow these steps to always have the latest version of this baseline:

```bash
cd aws-s3-baseline
git pull
cd ..
inspec archive aws-s3-baseline --overwrite
```

### Run your updated Archived Copy

`inspec exec <name of generated archive> --target aws:// --input-file=<path_to_your_inputs_file/name_of_your_inputs_file.yml> --reporter=cli json:<path_to_your_output_file/name_of_your_output_file.json>`

## Using Heimdall for Viewing the JSON Results

The JSON results output file can be loaded into **[Heimdall Lite](https://heimdall-lite.mitre.org/)** for a user-interactive, graphical view of the InSpec results.

The JSON InSpec results file can also be loaded into a **[full Heimdall server](https://github.com/mitre/heimdall)**, allowing for additional functionality such as storing and comparing multiple profile runs.

## Authors

- Rony Xavier - [rx294](https://github.com/rx294)
- Aaron Lippold - [aaronlippold](https://github.com/aaronlippold)
- Matthew Dromazos - [dromazmj](https://github.com/dromazmj)

### Special Thanks

- Shivani Karikar - [karikarshivani](https://github.com/karikarshivani)

### NOTICE

© 2018-2024 The MITRE Corporation.

Approved for Public Release; Distribution Unlimited. Case Number 18-3678.

### NOTICE

MITRE hereby grants express written permission to use, reproduce, distribute, modify, and otherwise leverage this software to the extent permitted by the licensed terms provided in the LICENSE.md file included with this project.

### NOTICE

This software was produced for the U.S. Government under Contract Number HHSM-500-2012-00008I and is subject to Federal Acquisition Regulation Clause 52.227-14, Rights in Data-General.

No other use other than that granted to the U.S. Government, or to those acting on behalf of the U.S. Government under that Clause, is authorized without the express written permission of The MITRE Corporation.

For further information, please contact The MITRE Corporation, Contracts Management Office, 7515 Colshire Drive, McLean, VA 22102-7539, (703) 983-6000.