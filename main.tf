provider "aws" {
  region = "us-east-1" # CloudTrail Lake is a global service
}

# configure KMS encryption
resource "aws_kms_key" "cloudtrail_lake" {
  description             = "KMS key for CloudTrail Lake encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_cloudtrail_event_data_store" "example" {
  name                       = "example-event-data-store"
  advanced_event_selector {
    name = "AllEvents"
    
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
    
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
  retention_period           = 2557 # 7 years in days
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
        Resource = "*"
      }
    ]
  })
}

# Output the ARN
output "event_data_store_arn" {
  value = aws_cloudtrail_event_data_store.example.arn
}
