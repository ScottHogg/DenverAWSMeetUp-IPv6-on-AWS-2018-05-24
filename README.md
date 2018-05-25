# DenverAWSMeetUp-IPv6-on-AWS-2018-05-24
Presentation, scripts, and notes from the Denver AWS MeetUp on 5/24/18

The topic of this presentation was IPv6 Running on AWS.

Here is the PDF of the lecture.  This is a compilation of the IPv6 features available in AWS.
Note: AWS continually updates their software and services so the IPv6 features listed here and their limitations may change at any moment without notice.

The second half of the presentation was a live demonstration of a fully dual-protocol AWS environment.

v6ApplicationVPC.yml is a CloudFormation Template that is based on the AWS NIST quickstart templates.
This CFT creates a VPC, obtains the /56 AWS prefix for the VPC, uses that to create /64 prefixes for the subnets, creates an IGW and EOIGW, routing tables, etc.

The AWS NIST QuickStart templates can be found here:
https://aws.amazon.com/quickstart/architecture/accelerator-nist/

awscli-ipv6.sh is a bash script that uses AWS CLI commands to perform the same tasks of creating a VPC, getting the /56, forming the /64s for the subnets, creating an IGW, EOIGW, and route table.

Note: This bash file is based on a script posted by Brad Simonin at:
https://medium.com/@brad.simonin/create-an-aws-vpc-and-subnet-using-the-aws-cli-and-bash-a92af4d2e54b
