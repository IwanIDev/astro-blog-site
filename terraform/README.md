# Astro blog AWS infrastructure

This Terraform configuration provisions the AWS hosting architecture for the Astro blog:

- A private S3 bucket for the generated `dist/` files.
- A CloudFront distribution using Origin Access Control to read from S3.
- An ACM certificate in `us-east-1` for the CloudFront HTTPS endpoint.
- Route 53 DNS validation and an alias record for the public hostname.
- A GitHub Actions OIDC provider and least-privilege IAM role for deployments.

## Usage

Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust the values if needed. The Route 53 hosted zone must already exist in the AWS account.

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

The apply outputs include the S3 bucket name, CloudFront distribution ID, and IAM role ARN needed by the deployment workflow.

The GitHub Actions workflow should assume `github_actions_role_arn`, sync `dist/` to `s3_bucket_name`, and create a CloudFront invalidation using `cloudfront_distribution_id`.
