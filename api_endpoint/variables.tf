variable "app_name" {
  type        = string
  description = "The name of the project in kebab-case."
}
variable "url" {
  type        = string
  description = "The url of the application. Ex: projectname.rll.byu.edu"
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
variable "lambda_environment_variables" {
  type        = map(string)
  description = "The environment variables to set on the Lambda functions."

}
variable "lambda_role_arn" {
  type        = string
  description = "The ARN of the Lambda Role to be attached to the Lambda function."
}

variable "path_part" {
  type        = string
  description = "The URL path to invoke the method."
}
variable "allowed_headers" {
  type        = string
  description = "The custom headers the endpoint should allow. Provided as a string with each header key separated by a comma."
}
variable "method_definitions" {
  type = list(object({
    http_method = string
    command     = list(string)
    timeout     = optional(number)
    memory_size = optional(number)
  }))
  description = "The definitions for each method of the endpoint."
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

