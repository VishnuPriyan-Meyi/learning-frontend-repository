#!/bin/bash

# =============================================================
# init.sh — Prerequisites Validation Script
#
# This script validates all prerequisites before running setup.
# It checks for:
#   - Required tools (AWS CLI, SAM CLI)
#   - AWS credentials and account access
#   - Environment configuration
#
# Usage:
#   source devops/init.sh
#   OR
#   ./devops/init.sh
# =============================================================

# ── Load utility functions ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
source "$SCRIPT_DIR/utils.sh"

# ── Validate AWS CLI ────────────────────────────────────────
validate_aws_cli_with_region() {
  echo "Validating AWS CLI..."
  
  AWS_ACCOUNT_ID=$(validate_aws_cli)
  ok "AWS CLI OK. Account: $AWS_ACCOUNT_ID | Region: ${AWS[REGION]}"
}

# ── Validate SAM CLI ────────────────────────────────────────
validate_sam_cli_with_message() {
  echo "Validating SAM CLI..."
  validate_sam_cli
  ok "SAM CLI OK."
}

# ── Validate Environment Configuration ───────────────────────
validate_env_config_full() {
  echo "Validating environment configuration..."
  
  load_env_config
  
  # Convert associative arrays to regular variables for validation
  GITHUB_ORG="${GITHUB[ORG]}"
  GITHUB_REPO="${GITHUB[REPO]}"
  GITHUB_BRANCH="${GITHUB[BRANCH]}"
  GITHUB_CONNECTION_ARN="${GITHUB[CONNECTION_ARN]}"
  AWS_REGION="${AWS[REGION]}"
  ENVIRONMENT_ENV="${ENVIRONMENT[ENV]}"
  STACK_INFRA_NAME="${STACK[INFRA_NAME]}"
  STACK_PIPELINE_NAME="${STACK[PIPELINE_NAME]}"
  FRONTEND_BUCKET_NAME="${FRONTEND[BUCKET_NAME]}"
  
  # Debug: Check if variables are loaded
  echo "DEBUG: GitHub ORG='$GITHUB_ORG'"
  echo "DEBUG: GitHub REPO='$GITHUB_REPO'"
  echo "DEBUG: GitHub BRANCH='$GITHUB_BRANCH'"
  echo "DEBUG: GitHub CONNECTION_ARN='$GITHUB_CONNECTION_ARN'"
  
  # Check GitHub config
  if [ -z "$GITHUB_ORG" ] || [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_BRANCH" ] || [ -z "$GITHUB_CONNECTION_ARN" ]; then
    fail "GitHub configuration is incomplete. Please check GITHUB array in dev.env.sh"
  fi
  
  # Check AWS config
  if [ -z "$AWS_REGION" ]; then
    fail "AWS configuration is incomplete. Please check AWS array in dev.env.sh"
  fi
  
  # Check Environment config
  if [ -z "$ENVIRONMENT_ENV" ]; then
    fail "Environment configuration is incomplete. Please check ENVIRONMENT array in dev.env.sh"
  fi
  
  # Check Stack config
  if [ -z "$STACK_INFRA_NAME" ] || [ -z "$STACK_PIPELINE_NAME" ]; then
    fail "Stack configuration is incomplete. Please check STACK array in dev.env.sh"
  fi
  
  # Check Frontend config
  if [ -z "$FRONTEND_BUCKET_NAME" ]; then
    fail "Frontend configuration is incomplete. Please check FRONTEND array in dev.env.sh"
  fi
  
  # Check for placeholder values
  if [[ "$GITHUB_ORG" == *"your-"* ]] || [[ "$GITHUB_REPO" == *"your-"* ]] || [[ "$FRONTEND_BUCKET_NAME" == *"your-"* ]]; then
    fail "Please replace placeholder values in dev.env.sh with your actual configuration"
  fi
  
  ok "Environment configuration OK."
}

# ── Run prerequisites validation ───────────────────────────────
validate_prerequisites() {
  # Check if validation should be skipped
  if [ "${SKIP_VALIDATION:-false}" = "true" ]; then
    echo "Skipping prerequisites validation..."
    return 0
  fi
  
  # Load environment config first to make arrays available globally
  load_env_config
  
  show_section "Prerequisites Validation"
  
  validate_aws_cli_with_region
  validate_sam_cli_with_message
  
  # Environment validation in main context to avoid function scoping issues
  echo "Validating environment configuration..."
  
  # Check GitHub config
  if [ -z "$GITHUB_ORG" ] || [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_BRANCH" ] || [ -z "$GITHUB_CONNECTION_ARN" ]; then
    fail "GitHub configuration is incomplete. Please check GITHUB array in dev.env.sh"
  fi
  
  # Check AWS config
  if [ -z "$AWS_REGION" ]; then
    fail "AWS configuration is incomplete. Please check AWS array in dev.env.sh"
  fi
  
  # Check Environment config
  if [ -z "$ENVIRONMENT_ENV" ]; then
    fail "Environment configuration is incomplete. Please check ENVIRONMENT array in dev.env.sh"
  fi
  
  # Check Stack config
  if [ -z "$STACK_INFRA_NAME" ] || [ -z "$STACK_PIPELINE_NAME" ]; then
    fail "Stack configuration is incomplete. Please check STACK array in dev.env.sh"
  fi
  
  # Check Frontend config
  if [ -z "$FRONTEND_BUCKET_NAME" ]; then
    fail "Frontend configuration is incomplete. Please check FRONTEND array in dev.env.sh"
  fi
  
  # Check for placeholder values
  if [[ "$GITHUB_ORG" == *"your-"* ]] || [[ "$GITHUB_REPO" == *"your-"* ]] || [[ "$FRONTEND_BUCKET_NAME" == *"your-"* ]]; then
    fail "Please replace placeholder values in dev.env.sh with your actual configuration"
  fi
  
  ok "Environment configuration OK."
  
  divider
  show_success_banner "All Prerequisites Validated! ✅"
}

# ── Run validation if script is executed directly ───────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  validate_prerequisites
fi

# Export functions for use in other scripts
export -f validate_prerequisites validate_aws_cli_with_region validate_sam_cli_with_message validate_env_config_full
