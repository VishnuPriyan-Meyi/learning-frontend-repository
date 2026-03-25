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
  validate_env_arrays
  
  ok "Environment configuration OK."
}

# ── Main Validation Function ───────────────────────────────────
validate_prerequisites() {
  show_section "Prerequisites Validation"
  
  validate_aws_cli_with_region
  validate_sam_cli_with_message
  validate_env_config_full
  
  divider
  show_success_banner "All Prerequisites Validated! ✅"
}

# ── Run validation if script is executed directly ───────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  validate_prerequisites
fi

# Export functions for use in other scripts
export -f validate_prerequisites validate_aws_cli_with_region validate_sam_cli_with_message validate_env_config_full
