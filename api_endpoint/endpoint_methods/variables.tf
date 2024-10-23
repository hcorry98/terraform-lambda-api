variable "app_name" {
  type        = string
  description = "The name of the project in kebab-case."
}
variable "ecr_repo" {
  type = object({
    name           = string,
    repository_url = string
  })
  description = "The ECR repository that contains the image for the lambda functions."
}
variable "image_tag" {
  type        = string
  description = "The image tag for the Docker image (the timestamp)."
}
variable "lambda_role_arn" {
  type        = string
  description = "The ARN of the Lambda Role to be attached to the Lambda function."
}
variable "path_part" {
  type        = string
  description = "The URL path to invoke the method."
}

variable "http_method" {
  type        = string
  description = "The HTTP methods for the endpoint."
}
variable "command" {
  type        = list(string)
  description = "The lambda handlers for each method of the endpoint. The syntax is file_name.function_name"
}
variable "lambda_environment_variables" {
  type        = map(string)
  description = "The environment variables to set on the Lambda function."
}
variable "timeout" {
  type        = number
  description = "Amount of time your Lambda Function has to run in seconds."
}

variable "memory_size" {
  type        = number
  description = "The amount of memory, in MB, your Lambda Function is given. Valid values are from 128 to 10,240. Default is 128. 1,769 is equivalent to 1 vCPU."
}

variable "api_gateway" {
  type = object({
    name             = string
    id               = string
    root_resource_id = string
    execution_arn    = string
  })
  description = "The API Gateway for the enpoints."
}
variable "api_resource_id" {
  type        = string
  description = "The ID for the API Resource for this endpoint."
}
