locals {
  endpoint_map = {
    for def in var.lambda_endpoint_definitions : "${var.app_name}_${def.path_part}" => {
      path_part          = def.path_part
      allowed_headers    = def.allowed_headers
      method_definitions = def.method_definitions
    }
  }
}

# ========== Miscellaneous Data ==========
module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v4.0.0"
}

# ========== Lambda Policies ==========
resource "aws_iam_role" "lambda_role" {
  name                 = var.app_name
  permissions_boundary = module.acs.role_permissions_boundary.arn
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "lambda.amazonaws.com"
        }
        Effect : "Allow",
        Sid : ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-policy-attachments" {
  count      = length(var.function_policies)
  policy_arn = element(var.function_policies, count.index)
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name = "${var.project_name}-cloudwatch"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-cloudwatch-policy-attachment" {
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# ========== API Endpoints ==========
resource "aws_api_gateway_rest_api" "api_gateway" {
  name = var.project_name
}

module "api_endpoint" {
  source = "./api_endpoint/"

  for_each = local.endpoint_map

  app_name                     = var.app_name
  url                          = var.url
  ecr_repo                     = var.ecr_repo
  image_tag                    = var.image_tag
  lambda_environment_variables = var.lambda_environment_variables
  lambda_role_arn              = aws_iam_role.lambda_role.arn

  path_part          = each.value.path_part
  allowed_headers    = each.value.allowed_headers
  method_definitions = each.value.method_definitions

  api_gateway = aws_api_gateway_rest_api.api_gateway
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  depends_on = [module.api_endpoint]

  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "${var.app_name}-stage"
}

# ========== Custom API URL ==========
data "aws_route53_zone" "domain_zone" {
  name = var.domain
}

resource "aws_api_gateway_domain_name" "api_gateway_domain_name" {
  depends_on = [aws_acm_certificate_validation.api_gateway_cert_validation]

  domain_name     = var.api_url
  certificate_arn = aws_acm_certificate.api_gateway_cert.arn
}

resource "aws_route53_record" "api_gateway_subdomain_A" {
  name    = var.api_url
  type    = "A"
  zone_id = data.aws_route53_zone.domain_zone.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_gateway_subdomain_AAAA" {
  name    = var.api_url
  type    = "AAAA"
  zone_id = data.aws_route53_zone.domain_zone.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api_gateway_domain_name.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_base_path_mapping" "api_gateway_base_path_mapping" {
  api_id      = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = aws_api_gateway_deployment.api_gateway_deployment.stage_name
  domain_name = aws_api_gateway_domain_name.api_gateway_domain_name.domain_name
}

# api-gateway / cloudfront certificates need to use the us-east-1 region
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

resource "aws_acm_certificate" "api_gateway_cert" {
  # api-gateway / cloudfront certificates need to use the us-east-1 region
  provider          = aws.virginia
  domain_name       = var.api_url
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "api_gateway_cert_validation" {
  # api-gateway / cloudfront certificates need to use the us-east-1 region
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.api_gateway_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.api_gateway_cert_validation : record.fqdn]
}

resource "aws_route53_record" "api_gateway_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_gateway_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  name    = each.value.name
  records = [each.value.record]
  type    = each.value.type

  zone_id = data.aws_route53_zone.domain_zone.zone_id
  ttl     = 60
}
