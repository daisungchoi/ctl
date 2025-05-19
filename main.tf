# Get current AWS account info dynamically
data "aws_caller_identity" "current" {}

# Create a KMS key for CloudTrail Lake
resource "aws_kms_key" "cloudtrail_lake" {
  description         = "KMS key for CloudTrail Lake event data store encryption"
  enable_key_rotation = true
  deletion_window_in_days = 7
}

# Attach a key policy to the KMS key
resource "aws_kms_key_policy" "cloudtrail_key_policy" {
  key_id = aws_kms_key.cloudtrail_lake.id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid       = "AllowRootAccountFullAccess",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudTrailUsage",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
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
