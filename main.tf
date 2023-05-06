provider "aws" {
    region = "us-east-2"
  
}

resource "aws_instance" "testec2" {
    ami = "ami-08333bccc35d71140"
    instance_type = "t2.micro"
    tags = {
        Name = "Terraform-example"
    }
  
}