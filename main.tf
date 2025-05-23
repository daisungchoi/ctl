# Get current AWS account info dynamically
data "aws_caller_identity" "current" {}

# Create a KMS key for CloudTrail Lake
resource "aws_kms_key" "cloudtrail_lake" {
  description         = "KMS key for CloudTrail Lake event data store encryption"
  enable_key_rotation = true
  deletion_window_in_days = 7
}

resource "aws_kms_key_policy" "cloudtrail_key_policy" {
  key_id = aws_kms_key.cloudtrail_lake.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailServiceUseOfTheKey",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource  = "*"
      },
      {
        Sid    = "AllowAccountUseOfTheKey",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource  = "*"
      }
    ]
  })
}

# Create a CloudTrail Event Data Store using the new KMS key
resource "aws_cloudtrail_event_data_store" "aft" {
  name       = "aft-event-data-store"
  kms_key_id = aws_kms_key.cloudtrail_lake.arn

  advanced_event_selector {
    name = "ManagementEventsOnly"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  retention_period = 90
}
