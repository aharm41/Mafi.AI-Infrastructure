variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "mafiai"
}

variable "domain_name" {
  description = "Apex domain for the Route 53 hosted zone, for example example.com."
  type        = string
}

variable "route53_zone_id" {
  description = "ID of the existing public Route 53 hosted zone for domain_name."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "menu_image" {
  description = "Fully-qualified menu container image."
  type        = string
}

variable "menu_environment" {
  description = "Non-secret environment variables for the menu container."
  type        = map(string)
  default     = {}
}

variable "game_image" {
  description = "Fully-qualified game container image."
  type        = string
}

variable "game_environment" {
  description = "Non-secret environment variables for the game container."
  type        = map(string)
  default     = {}
}

variable "openai_api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing OPENAI_API_KEY."
  type        = string
  sensitive   = true
}

variable "menu_cpu" {
  type    = number
  default = 256
}

variable "menu_memory" {
  type    = number
  default = 512
}

variable "game_cpu" {
  type    = number
  default = 512
}

variable "game_memory" {
  type    = number
  default = 1024
}

variable "menu_desired_count" {
  type    = number
  default = 1
}

variable "game_desired_count" {
  type    = number
  default = 1
}
