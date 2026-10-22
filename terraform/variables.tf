variable "aws_region" {
  description = "AWS region for the S3 bucket and regional resources."
  type        = string
  default     = "eu-north-1"
}

variable "domain_name" {
  description = "Primary public hostname for the site."
  type        = string
  default     = "www.iwaningman.com"
}

variable "root_domain_name" {
  description = "Apex hostname that redirects to the primary public hostname."
  type        = string
  default     = "iwaningman.com"
}

variable "hosted_zone_name" {
  description = "Route 53 hosted zone name, including the trailing dot."
  type        = string
  default     = "iwaningman.com."
}

variable "comments_ip_address" {
  description = "IPv4 address for the comments hostname."
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the deployment role."
  type        = string
  default     = "IwanIDev/astro-blog-site"
}

variable "github_branch" {
  description = "GitHub branch allowed to deploy production files."
  type        = string
  default     = "master"
}

variable "bucket_name" {
  description = "Optional globally unique S3 bucket name. Leave null to derive one from the domain."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all supported AWS resources."
  type        = map(string)
  default = {
    Project   = "astro-blog-site"
    ManagedBy = "terraform"
  }
}
