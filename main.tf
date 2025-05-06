provider "aws" {
  region = "us-east-1" # CloudTrail Lake is a global service
}

# Check STS 
data "aws_caller_identity" "current" {}

# configure KMS encryption
resource "aws_kms_key" "cloudtrail_lake" {
  description             = "KMS key for CloudTrail Lake encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.cloudtrail_lake_kms_policy.json
}

data "aws_iam_policy_document" "cloudtrail_kms_policy" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::797090772946:user/dchoi"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Allow CloudTrail to encrypt logs"
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EnableCloudTrailLakeQuery"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:us-east-1:${data.aws_caller_identity.current.account_id}:eventdatastore/*"]
    }
  }
}

resource "aws_cloudtrail_event_data_store" "aft" {
  name                       = "aft-event-data-store"
  advanced_event_selector {
    name = "AllEvents"
    
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
  }
  
  multi_region_enabled       = true
  organization_enabled       = true # Enable for all accounts in organization
  retention_period           = 365 # 7 years in days
  termination_protection_enabled = false
  kms_key_id = aws_kms_key.cloudtrail_lake.arn

  # Add tags
  tags = {
    Environment = "Production"
    Department  = "Security"
  }
}

# Add IAM permission
resource "aws_iam_policy" "cloudtrail_lake_query" {
  name        = "CloudTrailLakeQueryAccess"
  description = "Allows querying CloudTrail Lake"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudtrail:StartQuery",
          "cloudtrail:GetQueryResults",
          "cloudtrail:DescribeQuery"
        ]
        Resource = aws_cloudtrail_event_data_store.aft.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.cloudtrail_lake_kms.arn
      }
    ]
  })
}

# Output the ARN
output "event_data_store_arn" {
  value = aws_cloudtrail_event_data_store.aft.arn
}
