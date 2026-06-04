variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "lab_tag" {
  description = "Tag value used to identify all lab resources"
  type        = string
  default     = "m7-04"
}

variable "environment" {
  description = "Environment tag applied to all instances"
  type        = string
  default     = "development"
}