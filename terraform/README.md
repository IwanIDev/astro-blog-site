# Astro blog AWS infrastructure

This Terraform configuration provisions the AWS hosting architecture for the Astro blog:

- A private S3 bucket for the generated `dist/` files.
- A CloudFront distribution using Origin Access Control to read from S3.
- An ACM certificate in `us-east-1` for the CloudFront HTTPS endpoint.
- Route 53 DNS validation and an alias record for the public hostname.
- A GitHub Actions OIDC provider and least-privilege IAM role for deployments.

## Usage

The Route 53 hosted zone must already exist in the AWS account. The first deployment also needs:

- An S3 bucket for Terraform state, configured as the `TF_STATE_BUCKET` GitHub repository variable.
- An existing AWS IAM role trusted by this repository's GitHub OIDC subject, configured as the `TERRAFORM_ROLE_ARN` repository variable. This bootstrap role needs permission to manage the resources in `main.tf`.
- An optional `AWS_REGION` repository variable; it defaults to `eu-west-2`.

The bootstrap role is only needed to run Terraform. Terraform creates the narrower `github_actions_role_arn` role, which the workflow assumes for subsequent S3 and CloudFront deployment steps.

For local use, copy `terraform.tfvars.example` to `terraform.tfvars` and adjust the values if needed:

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

For a local backend initialization, supply the state bucket explicitly:

```sh
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=astro-blog-site/terraform.tfstate" \
  -backend-config="region=eu-west-2" \
  -backend-config="use_lockfile=true"
```

The apply outputs include the S3 bucket name, CloudFront distribution ID, and IAM role ARN used by the GitHub Actions deployment.
