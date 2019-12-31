variable "name" {
    default = "test"
}

variable "region"
{
    default = "eu-central-1"
}

variable "aws_ubuntu_awis"
{
    default = {
        "eu-central-1" = "ami-0cc0a36f626a4fdf5 "
    }
}