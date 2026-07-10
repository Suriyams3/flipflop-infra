# ==============================================================================
# AWS SECRETS MANAGER CONFIGURATION (secrets.tf)
# ==============================================================================

# 1. Define the Secret Container (The Envelope)
resource "aws_secretsmanager_secret" "db_creds" {
  name        = "flipflop_db_creds"
  description = "Database administrative credentials for the FlipFlop microservices cluster"

  # Optional but recommended: Forces clean tracking if you destroy/recreate often
  recovery_window_in_days = 0

  tags = {
    Environment = "Dev"
    Project     = "FlipFlop"
  }
}

# 2. Define the Secret Content (The Key-Value Payload)
resource "aws_secretsmanager_secret_version" "db_creds_payload" {
  secret_id     = aws_secretsmanager_secret.db_creds.id

  # Converts the HCL map into a JSON string required by AWS "Other type of secret"
  secret_string = jsonencode({
    db_password = "FlipFlopRootPass123!"
  })
}

# ==============================================================================
# OUTPUTS (For mapping directly into your database or microservice scripts)
# ==============================================================================
output "secrets_manager_secret_arn" {
  value       = aws_secretsmanager_secret.db_creds.arn
  description = "The Amazon Resource Name (ARN) identifying the created secret"
}