locals {
  method_map = {
    for def in var.method_definitions : "${var.app_name}_${var.path_part}_${def.http_method}" => {
      http_method = def.http_method
      command     = def.command
      timeout     = def.timeout
      memory_size = def.memory_size
    }
  }

  http_methods        = [for def in var.method_definitions : def.http_method]
  http_methods_string = join(",", local.http_methods)
}

# ========== API Gateway ==========
# ----- Endpoint -----
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = var.api_gateway.id
  parent_id   = var.api_gateway.root_resource_id
  path_part   = var.path_part
}

# ----- Methods -----
module "endpoint_methods" {
  source = "./endpoint_methods/"

  for_each = local.method_map

  app_name                     = var.app_name
  ecr_repo                     = var.ecr_repo
  image_tag                    = var.image_tag
  lambda_environment_variables = var.lambda_environment_variables
  lambda_role_arn              = var.lambda_role_arn
  path_part                    = var.path_part

  http_method = each.value.http_method
  command     = each.value.command
  timeout     = each.value.timeout
  memory_size = each.value.memory_size

  api_gateway     = var.api_gateway
  api_resource_id = aws_api_gateway_resource.api_resource.id
}

# ----- Options Method -----
resource "aws_api_gateway_method" "api_options_method" {
  rest_api_id   = var.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_options_integration" {
  rest_api_id = var.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration_response" "api_options_integration_response" {
  rest_api_id = var.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_options_method.http_method
  status_code = aws_api_gateway_method_response.api_options_method_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = var.allowed_headers != null ? "'Content-Type,${var.allowed_headers}'" : "'Content-Type'",
    "method.response.header.Access-Control-Allow-Methods" = "'${local.http_methods_string},OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${var.url}'",
  }
}

resource "aws_api_gateway_method_response" "api_options_method_response" {
  rest_api_id = var.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_options_method.http_method
  status_code = 200
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
