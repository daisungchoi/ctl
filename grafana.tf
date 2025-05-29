# Create IAM Role for Grafana
{
  "resource": {
    "aws_iam_role": {
      "grafana_role": {
        "name": "GrafanaAthenaAccessRole",
        "assume_role_policy": "{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Effect\": \"Allow\",\n      \"Principal\": {\n        \"Service\": \"grafana.amazonaws.com\"\n      },\n      \"Action\": \"sts:AssumeRole\"\n    }\n  ]\n}"
      }
    },
    "aws_iam_role_policy_attachment": {
      "attach_athena_policy": {
        "role": "${aws_iam_role.grafana_role.name}",
        "policy_arn": "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
      }
    }
  }
}

# Create the Grafana Workspace

{
  "resource": {
    "aws_grafana_workspace": {
      "cloudtrail_workspace": {
        "account_access_type": "CURRENT_ACCOUNT",
        "authentication_providers": [
          "AWS_SSO"
        ],
        "permission_type": "SERVICE_MANAGED",
        "name": "cloudtrail-logs-grafana",
        "data_sources": [
          "ATHENA"
        ],
        "role_arn": "${aws_iam_role.grafana_role.arn}"
      }
    }
  }
}
