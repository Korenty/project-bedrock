variable "aws_region" {
  description = "The mandatory AWS region for Project Bedrock"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "The mandatory VPC name tag for the automated grader"
  type        = string
  default     = "project-bedrock-vpc"
}

variable "student_id" {
  description = "Your unique AltSchool student ID identifier formatted for AWS resource naming"
  type        = string
  default     = "alt-soe-025-3173"
}