#!/bin/bash

# =============================================================
# init.sh — Prerequisites Validation Script
#
# This script validates basic prerequisites before running setup.
# It checks for:
#   - Required tools (AWS CLI, SAM CLI)
#   - AWS credentials and account access
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


# ── Run prerequisites validation ───────────────────────────────
validate_prerequisites() {
  # Check if validation should be skipped
  if [ "${SKIP_VALIDATION:-false}" = "true" ]; then
    echo "Skipping prerequisites validation..."
    return 0
  fi
  
  show_section "Prerequisites Validation"
  
  validate_aws_cli_with_region
  validate_sam_cli_with_message
  
  divider
  show_success_banner "All Prerequisites Validated! ✅"
}

# ── Run validation if script is executed directly ───────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  validate_prerequisites
fi

# Export functions for use in other scripts
export -f validate_prerequisites validate_aws_cli_with_region validate_sam_cli_with_message
