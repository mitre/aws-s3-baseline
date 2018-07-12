# fixtures = {}
# [
#   'ec2_security_group_default_vpc_id',
#   'ec2_security_group_default_group_id',
#   'ec2_security_group_allow_all_group_id',
# ].each do |fixture_name|
#   fixtures[fixture_name] = attribute(
#     fixture_name,
#     default: "default.#{fixture_name}",
#     description: 'See ../build/ec2.tf',
#   )
# end

# control "cis_aws_foundations-4.1" do
#   impact 0.7
#   title "4.1 Ensure no security groups allow ingress from 0.0.0.0/0 to port 22"
#   desc "Security groups provide stateful filtering of ingress/egress network
#         traffic to AWS resources. It is recommended that no security group allows unrestricted
#         ingress access to port 22."
#   tag "nist": ["SC-7(5)","Rev_4"]
#   tag "severity": "high"

#   tag "check": "
#       1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#       2. In the left pane, click Security Groups
#       3. For each security group, perform the following:
#         1. Select the security group
#         2. Click the Inbound Rules tab
#         3. Ensure no rule exists that has a port range that includes port 22 and
#            has a Source of 0.0.0.0/0 Note: A Port value of ALL or a port range
#            such as 0-1024 are inclusive of port 22. "
#   tag "fix": "
#       1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#       2. In the left pane, click Security Groups
#       3. For each security group, perform the following:
#         1. Select the security group
#         2. Click the Inbound Rules tab
#         3. Identify the rules to be removed
#         4. Click the x in the Remove column
#         5. Click Save "

#   describe aws_ec2_security_group(fixtures['ec2_security_group_allow_all_group_id']) do
#     it { should_not be_open_on_port(22) }
#   end
# end

# control "cis_aws_foundations-4.2" do
#   impact 0.7
#   title "4.2 Ensure no security groups allow ingress from 0.0.0.0/0 to port 3389"
#   desc "Security groups provide stateful filtering of ingress/egress network traffic
#         to AWS resources. It is recommended that no security group allows unrestricted
#         ingress access to port 3389."
#   tag "nist": ["SC-7(5)","Rev_4"]
#   tag "severity": "high"
#   tag "check": "Perform the following to determine if the account is configured as prescribed:
#       1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#       2. In the left pane, click Security Groups
#       3. For each security group, perform the following:
#         1. Select the security group
#         2. Click the Inbound Rules tab
#         3. Ensure no rule exists that has a port range that includes port 3389
#            and has a Source of 0.0.0.0/0 "
#   tag "fix": "
#       1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#       2. In the left pane, click Security Groups
#       3. For each security group, perform the following:
#         1. Select the security group
#         2. Click the Inbound Rules tab
#         3. Identify the rules to be removed
#         4. Click the x in the Remove column
#         5. Click Save "

#   describe aws_ec2_security_group(fixtures['ec2_security_group_allow_all_group_id']) do
#     it { should_not be_open_on_port(3389) }
#   end
# end

# control "cis_aws_foundations-4.4" do
#   impact 0.7
#   title "Ensure the default security group of every VPC restricts all traffic "
#   desc "A VPC comes with a default security group whose initial settings deny all
#         inbound traffic, allow all outbound traffic, and allow all traffic between
#         instances assigned to the security group. If you don't specify a security group
#         when you launch an instance, the instance is automatically assigned to this
#         default security group. Security groups provide stateful filtering of
#         ingress/egress network traffic to AWS resources. It is recommended that
#         the default security group restrict all traffic. The default VPC in every
#         region should have it's default security group updated to comply.  Any newly
#         created VPCs will automatically contain a default security group that will
#         need remediation to comply with this recommendation. "
#   tag "nist": ["SC-7(5)","Rev_4"]
#   tag "severity": "high"
#   tag "check": "Perform the following to determine if the account is configured as prescribed:
#         Security Group State
#           1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#           2. Repeat the next steps for all VPCs - including the default VPC in each AWS region:
#           3. In the left pane, click Security Groups
#           4. For each default security group, perform the following:
#             1. Select the default security group
#             2. Click the Inbound Rules tab
#             3. Ensure no rule exist
#             4. Click the Outbound Rules tab
#             5. Ensure no rules exist
#         Security Group Members
#           1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#           2. Repeat the next steps for all default groups in all VPCs - including the default VPC in each AWS region:
#           3. In the left pane, click Security Groups
#           4. Copy the id of the default security group.
#           5. Change to the EC2 Management Console at https://console.aws.amazon.com/ec2/v2/home
#           6. In the filter column type 'Security Group ID : <security group id from #4>'"
#   tag "fix": "
#         Security Group Members
#           1. Identify AWS resources that exist within the default security group
#           2. Create a set of least privilege security groups for those resources
#           3. Place the resources in those security groups
#           4. Remove the resources noted in #1 from the default security group
#         Security Group State
#           1. Login to the AWS Management Console at https://console.aws.amazon.com/vpc/home
#           2. Repeat the next steps for all VPCs - including the default VPC in each AWS region:
#           3. In the left pane, click Security Groups
#           4. For each default security group, perform the following:
#             1. Select the default security group
#             2. Click the Inbound Rules tab
#             3. Remove any inbound rules
#             4. Click the Outbound Rules tab
#             5. Remove any {outbound} rules"

#     # You should be able to find the security group named default
#     describe aws_ec2_security_group(group_id: fixtures['ec2_security_group_default_group_id']) do
#       it { should exist }
#       its('ingress_rules.count') { should eq 0 }
#       its('egress_rules.count') { should eq 0 }
#     end

#     describe aws_ec2_security_group(group_id: fixtures['ec2_security_group_allow_all_group_id']) do
#       it { should exist }
#       its('ingress_rules') { should cmp [] }
#       its('egress_rules')  { should cmp [] }
#     end
#   end
