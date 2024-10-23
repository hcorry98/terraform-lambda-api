# ========== Lambda ==========
# ----- Function -----
resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.app_name}_${var.path_part}_${var.http_method}"
  role          = var.lambda_role_arn
  package_type  = "Image"
  image_uri     = "${var.ecr_repo.repository_url}:${var.app_name}-${var.image_tag}"
  timeout       = var.timeout
  memory_size   = var.memory_size
  image_config {
    command = var.command
  }
  environment {
    variables = var.lambda_environment_variables
  }
}

resource "aws_lambda_permission" "lambda-permission" {
  statement_id  = "Allow${var.api_gateway.name}APIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${var.api_gateway.execution_arn}/*"
}

# ========== API Gateway ==========
# ----- Method -----
resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = var.api_gateway.id
  resource_id   = var.api_resource_id
  http_method   = var.http_method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id             = var.api_gateway.id
  resource_id             = var.api_resource_id
  http_method             = aws_api_gateway_method.api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

# ========== Cloudwatch ==========
resource "aws_cloudwatch_log_group" "LambdaFunctionLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function.function_name}"
  retention_in_days = 7
}
