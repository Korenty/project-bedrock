# ==============================================================================
# PHASE 4: EVENT-DRIVEN SERVERLESS EXTENSION
# ==============================================================================
# This configuration creates the private asset storage S3 bucket, a secure Lambda
# function, and configures event notifications to trigger whenever files are uploaded.

# 1. Archive the Lambda Python script into a ZIP archive for deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

# 2. Mandated S3 Assets Bucket (Section 4.5)
resource "aws_s3_bucket" "assets_bucket" {
  # Naming convention mandated by the technical constraints (Section 1)
  bucket        = "bedrock-assets-alt-soe-025-3173"
  force_destroy = true # Allows clean tear down when destroying the project

  tags = {
    Name    = "bedrock-assets-alt-soe-025-3173"
    Project = "karatu-2025-capstone"
  }
}

# Ensure S3 Bucket is private by blocking public access
resource "aws_s3_bucket_public_access_block" "assets_bucket_pab" {
  bucket                  = aws_s3_bucket.assets_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. IAM Role for Lambda execution with CloudWatch logging permissions
resource "aws_iam_role" "lambda_role" {
  name = "bedrock-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# Attach basic execution policy to allow Lambda to output logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. Mandated Lambda Function (Section 4.5)
resource "aws_lambda_function" "processor" {
  function_name    = "bedrock-asset-processor"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 15

  tags = {
    Name    = "bedrock-asset-processor"
    Project = "karatu-2025-capstone"
  }
}

# 5. S3 Bucket Permission to Invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets_bucket.arn
}

# 6. S3 Event Notification Trigger
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.assets_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}