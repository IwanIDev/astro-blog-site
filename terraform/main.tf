data "aws_caller_identity" "current" {}

data "aws_route53_zone" "site" {
  name         = var.hosted_zone_name
  private_zone = false
}

data "aws_iam_policy_document" "route53_dnssec_kms" {
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowRoute53DnssecSigning"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["route53.amazonaws.com"]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.site.zone_id}"]
    }
  }
}

resource "aws_kms_key" "route53_dnssec" {
  provider                 = aws.us_east_1
  description              = "Route 53 DNSSEC signing key for ${var.hosted_zone_name}"
  customer_master_key_spec = "RSA_2048"
  key_usage                = "SIGN_VERIFY"
  policy                   = data.aws_iam_policy_document.route53_dnssec_kms.json
}

resource "aws_route53_key_signing_key" "site" {
  hosted_zone_id             = data.aws_route53_zone.site.zone_id
  key_management_service_arn = aws_kms_key.route53_dnssec.arn
  name                       = "iwaningman-com"
}

resource "aws_route53_hosted_zone_dnssec" "site" {
  hosted_zone_id = data.aws_route53_zone.site.zone_id

  depends_on = [aws_route53_key_signing_key.site]
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

locals {
  bucket_name = coalesce(var.bucket_name, "${replace(var.domain_name, ".", "-")}-${data.aws_caller_identity.current.account_id}")
  origin_id   = "s3-${local.bucket_name}"
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  // Lifecycle rules
  rule {
    id     = "clean-up-old-site-versions"
    status = "Enabled"

    filter {}

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      // Expire noncurrent versions after 30 days
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      // Abort incomplete multipart uploads after 7 days
      days_after_initiation = 7
    }
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.domain_name}-oac"
  description                       = "CloudFront access to the private Astro site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "site" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  subject_alternative_names = [var.root_domain_name]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.site.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.site.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

resource "aws_cloudfront_function" "directory_index" {
  name    = "astro-blog-directory-index"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Redirect apex domain and map Astro pretty URLs to index.html files"

  code = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      var host = request.headers.host.value;
      var query = '';
      var queryKeys = Object.keys(request.querystring);

      if (queryKeys.length > 0) {
        var queryParts = [];

        queryKeys.forEach(function (key) {
          var parameter = request.querystring[key];

          if (parameter.multiValue) {
            parameter.multiValue.forEach(function (value) {
              queryParts.push(key + '=' + value.value);
            });
          } else {
            queryParts.push(key + '=' + parameter.value);
          }
        });

        query = '?' + queryParts.join('&');
      }

      if (host === "${var.root_domain_name}") {
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            location: {
              value: 'https://${var.domain_name}' + uri + query
            }
          }
        };
      }

      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (!uri.includes('.')) {
        request.uri = uri + '/index.html';
      }

      return request;
    }
  EOF
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "Astro blog - ${var.domain_name}"
  default_root_object = "index.html"
  aliases             = [var.domain_name, var.root_domain_name]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.directory_index.arn
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "AllowCloudFrontReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket.json
}

data "aws_iam_policy_document" "github_deploy_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "github-actions-${replace(var.domain_name, ".", "-")}"
  assume_role_policy = data.aws_iam_policy_document.github_deploy_assume_role.json
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "SyncSiteFiles"
    effect    = "Allow"
    actions   = ["s3:DeleteObject", "s3:GetObject", "s3:ListBucket", "s3:PutObject"]
    resources = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid       = "InvalidateCloudFront"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy-static-site"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

resource "aws_route53_record" "site" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = var.root_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "comments" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = "comments.iwaningman.com"
  type    = "A"
  ttl     = 300
  records = [var.comments_ip_address]
}
