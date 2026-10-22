# Astro blog AWS infrastructure

This Terraform configuration provisions the AWS hosting architecture for the Astro blog:

- A private S3 bucket for the generated `dist/` files.
- A CloudFront distribution using Origin Access Control to read from S3.
- A CloudFront Function that redirects the apex domain to `www` and maps Astro pretty URLs to generated `index.html` files.
- An ACM certificate in `us-east-1` for the CloudFront HTTPS endpoint.
- Route 53 DNS validation and alias records for the apex and `www` hostnames.
- A GitHub Actions OIDC provider and least-privilege IAM role for deployments.

## Usage

The Route 53 hosted zone must already exist in the AWS account. The first deployment also needs:

- An S3 bucket for Terraform state, configured as the `TF_STATE_BUCKET` GitHub repository variable.
- An existing AWS IAM role trusted by this repository's GitHub OIDC subject, configured as the `TERRAFORM_ROLE_ARN` repository variable. This bootstrap role needs permission to manage the resources in `main.tf`.
- An optional `AWS_REGION` repository variable; it defaults to `eu-north-1`.

The bootstrap role is only needed to run Terraform. Terraform creates the narrower `github_actions_role_arn` role, which the workflow assumes for subsequent S3 and CloudFront deployment steps.

For local use, copy both example files and adjust the values. The state bucket must already exist:

```sh
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit backend.hcl and replace the bucket name.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Alternatively, initialize without creating a local backend file:

```sh
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=astro-blog-site/terraform.tfstate" \
  -backend-config="region=eu-north-1" \
  -backend-config="use_lockfile=true"
```

Because Terraform backend settings cannot use input variables, a plain `terraform init` cannot determine the S3 state bucket and will fail. The GitHub Actions workflow supplies the bucket and region through `-backend-config` automatically.

The apply outputs include the S3 bucket name, CloudFront distribution ID, and IAM role ARN used by the GitHub Actions deployment.
