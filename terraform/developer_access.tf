# ==============================================================================
# PHASE 4: SECURE DEVELOPER ACCESS
# ==============================================================================
# This configuration creates the 'bedrock-dev-view' IAM user, sets up console
# read-only policies, allows S3 bucket uploading, and links them to EKS RBAC.

# 1. Create the IAM User
resource "aws_iam_user" "dev_user" {
  name          = "bedrock-dev-view"
  force_destroy = true

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# 2. Enable Console login credentials
resource "aws_iam_user_login_profile" "dev_login" {
  user                    = aws_iam_user.dev_user.name
  password_reset_required = false
}

# Generate programmatic API keys for the grader (Section 4.3 Deliverables)
resource "aws_iam_access_key" "dev_keys" {
  user = aws_iam_user.dev_user.name
}

# 3. Attach AWS Managed ReadOnlyAccess policy for Console operations (Section 4.3)
resource "aws_iam_user_policy_attachment" "console_read_only" {
  user       = aws_iam_user.dev_user.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 4. Create custom inline policy to allow S3 uploading (PutObject) to the assets bucket
resource "aws_iam_user_policy" "s3_upload_policy" {
  name = "bedrock-dev-s3-upload-policy"
  user = aws_iam_user.dev_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Resource = "${aws_s3_bucket.assets_bucket.arn}/*"
      }
    ]
  })
}

# 5. Connect the IAM user to EKS Access Entries (Kubernetes RBAC)
# This securely maps the IAM user to the EKS cluster under the standard "view" clusterrole.
resource "aws_eks_access_entry" "dev_access" {
  cluster_name      = "project-bedrock-cluster"
  principal_arn     = aws_iam_user.dev_user.arn
  kubernetes_groups = ["viewers"] # Maps to our internal viewer group
  type              = "STANDARD"

  tags = {
    Project = "karatu-2025-capstone"
  }
}

# Associate the standard AmazonEKSViewPolicy with this access entry
resource "aws_eks_access_policy_association" "dev_policy" {
  cluster_name = "project-bedrock-cluster"
  # FIXED: Changed from AmazonEKSViewerPolicy to AmazonEKSViewPolicy to match AWS's exact API naming convention
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_user.dev_user.arn

  access_scope {
    type       = "namespace"
    namespaces = ["retail-app"] # Limits access strictly to our retail namespace
  }
}

# ------------------------------------------------------------------------------
# 6. OUTPUTS FOR YOUR DELIVERABLES / GRADING
# ------------------------------------------------------------------------------
output "grader_iam_username" {
  value = aws_iam_user.dev_user.name
}

output "grader_console_password" {
  value     = aws_iam_user_login_profile.dev_login.password
  sensitive = true # Marked sensitive to satisfy Terraform state compilation requirements
}

output "grader_access_key_id" {
  value = aws_iam_access_key.dev_keys.id
}

output "grader_secret_access_key" {
  value     = aws_iam_access_key.dev_keys.secret
  sensitive = true # Marked sensitive to satisfy Terraform state compilation requirements
}