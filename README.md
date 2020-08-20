provider "aws" {
region = "us-east-2"
}

resource "aws_key_pair" "sshkey" {
  key_name   = "user02-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCnP9+JqucAu0meragFTu49pMXTEsJSO3+fH9UPJNqHwG4UUz1DUB0vvvPq783pukwHvgH1zvmjtvlz5FqxB87QsTr/dEjSMdlzFADWexcq7HirYJXmZBFofwhpkvCEBA5eUyqwWt/CH86rroarnVIvK58j8/3FxuHH+tW9fyEhzPuMbJMm7+y+h5ttfbp/kG/acZBMpMkN2eZmWOs5Q5BK2dQEtQFPmHLdsFBhfglp32GqRa4iiMCQd7KAP21EDrm0MSw8kTHX8xHTR5Igazi+6TRFECo6qnjD4wUlSeDAhdvGr495DwIFMXwoEkL2Wk+1zPlt8qZ4JksKyaRm8YN ec2-user@ip-172-31-39-43"
}


## AWS CICD 샘플로 배포하시는 경우 Amazon LINUX 1세대 AMI 사용
variable "amazon_linux" {
  default = "ami-0f4aeaec5b3ce9152"
}

variable "user02_keyname" {
  default = "user02-key"
}

## Region별 ALB Account ID 별도 지정
## https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html 
variable "alb_account_id" {
  default = "033677994240"
  }

resource "aws_vpc" "dev" { 
cidr_block = "2.0.0.0/16" 
enable_dns_hostnames = true
enable_dns_support =true
instance_tenancy ="default"
tags = {
Name = "dev"
} 
}

resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.dev.id
  ## vpc_id            = "vpc-026af350fc64456e3"  // 직접 VPC ID로 넣어도 동작
  availability_zone = "us-east-2a"
  cidr_block        = "2.0.1.0/24"

  tags  = {
    Name = "public-1a"
  }
}


resource "aws_subnet" "public_1b" {
  vpc_id            = aws_vpc.dev.id
  availability_zone = "us-east-2b"
  cidr_block        = "2.0.2.0/24"

  tags  = {
    Name = "public-1b"
  }
}

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "dev"
  }
}

resource "aws_route_table" "dev_public" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id
  }

  tags = {
    Name = "dev-public"
  }
}

resource "aws_route_table_association" "dev_public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.dev_public.id
}

resource "aws_route_table_association" "dev_public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.dev_public.id
}

resource "aws_s3_bucket" "alb" {
  bucket = "sk-demo-alb-log.com"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.alb_account_id}:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::sk-demo-alb-log.com/*"
    }
  ]
}
  EOF

  lifecycle_rule {
    id      = "log_lifecycle"
    prefix  = ""
    enabled = true

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_default_security_group" "dev_default" {
  vpc_id = "${aws_vpc.dev.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-default"
  }
}

resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "open ssh port"

  vpc_id = "${aws_vpc.dev.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id = "${aws_vpc.dev.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP Security Group"
  }
}

resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id = "${aws_vpc.dev.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  
  
  tags = {
    Name = "Allow HTTP through ELB Security Group"
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    "${aws_security_group.elb_http.id}"
  ]
  subnets = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1b.id}"
  ]
  cross_zone_load_balancing   = true
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = "ami-0f4aeaec5b3ce9152" # Amazon Linux AMI 2018.03.0 (HVM)
  instance_type = "t2.micro"
  key_name = "${var.user02_keyname}"

  security_groups = ["${aws_security_group.elb_http.id}"]
  associate_public_ip_address = true

   user_data = <<USER_DATA
#!/bin/bash
yum update -y

#### AWS DevOps 샘플로 배포하시는 경우 아래 내용 무시하시고 CodeDeploy Agent만 설치
## 본인 지정 리전코드로 변경작업 필요 
## 예) 
yum -y install https://aws-codedeploy-us-east-2.s3.amazonaws.com/latest/codedeploy-agent.noarch.rpm
##yum -y install https://s3-us-east-2.amazonaws.com/aws-codedeploy-us-east-2/samples/latest/SampleApp_Linux.zip
sudo service codedeploy-agent start 

sudo su -
yum update -y
#sudo yum install ruby
#sudo yum install wget
yum install httpd -y
systemctl start httpd.service
#cd /home/ec2-user
#wget https://aws-codedeploy-us-east-2.s3.us-east-2.amazonaws.com/latest/install
#sudo ./install auto
#sudo service codedeploy-agent start

#### ALB만 설정하는 경우 아래 사용
#sudo yum -y install httpd
#echo "<html>" > /var/www/html/index.html
#echo "Hello" >> /var/www/html/index.html
#echo "<p> SERVER IP: $(curl *://169.254.169.254/latest/meta-data/local-ipv4) </p>" >> /var/www/html/index.html
#echo "<img src=\"CloudFront URL\">" >> /var/www/html/index.html
#echo "</html>" >> /var/www/html/index.html
#systemctl start httpd.service
 USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 3

  health_check_type    = "ELB"
  load_balancers= [
    "${aws_elb.web_elb.id}"
  ]

  launch_configuration = "${aws_launch_configuration.web.name}"
  ####  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]  아ㅐㄹ vpc_zone_identifier 와 중복

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity="1Minute"

  vpc_zone_identifier  = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1b.id}"
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}
