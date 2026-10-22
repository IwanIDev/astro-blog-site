output "s3_bucket_name" {
  description = "S3 bucket receiving the Astro build output."
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for cache invalidations."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution hostname."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC deployment."
  value       = aws_iam_role.github_deploy.arn
}

output "site_url" {
  description = "Public site URL."
  value       = "https://${var.domain_name}"
}

output "route53_dnssec_ds_record" {
  description = "DS record to publish at the domain registrar to complete DNSSEC activation."
  value       = aws_route53_key_signing_key.site.ds_record
}
