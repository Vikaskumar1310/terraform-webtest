provider "aws" {
    region = "ap-south-1"
    profile = "aws1profile"
}

//key-pair creation
resource "aws_key_pair" "terrakey" {
  key_name   = "terra-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41"
}

//security group creation
resource "aws_security_group" "Security" {
  name        = "terra-security"
  description = "Allow SSH and HTTP "

  ingress {
    description = "allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terra-security"
  }
}


//instance creation
resource "aws_instance" "web" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "cloudkey"
    security_groups = [ aws_security_group.Security.name ]

    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/Users/vikaskumar/Documents/cloud/cloudkey.pem")
    host     = aws_instance.web.public_ip
    }

    provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo yum install git -y"
      ]
    }

    tags = {
     Name = "terraos1"
    }
}

//EBS volume creation
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "terra_webos_ebs"
  }
}

//volume attachment with instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.web.id
  force_detach = true
}


//mounting the external storage and puting website page code
resource "null_resource" "nullremote3"  {
depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/Users/vikaskumar/Documents/cloud/cloudkey.pem")
    host     = aws_instance.web.public_ip
    }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Vikaskumar1310/terraform-webtest.git /var/www/html/"
    ]
  }
}



//s3 volume creation
resource "aws_s3_bucket" "vk13" {
    bucket = "vk13"
    acl    = "public-read"

    tags = {
	Name    = "vk-myterra-s3-bucket"
	Environment = "Dev"
    }
    versioning {
	enabled =true
    }
}


//Creating Cloudfront

resource "aws_cloudfront_distribution" "terracloudfront" {
    origin {
        domain_name = "vk13.s3.amazonaws.com"
        origin_id = "S3-vk13" 


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-vk13"

		//specify how cloudFront handles query strings, cookies and headers
        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        min_ttl                = 0
    	default_ttl            = 3600
    	max_ttl                = 86400
        viewer_protocol_policy = "allow-all"
    }
    # Restricts who can access this website
    restrictions {
        geo_restriction {
            # restriction type, blacklist, whitelist or none
            restriction_type = "none"
        }
    }
	// SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}


