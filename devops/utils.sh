#!/bin/bash

# =============================================================
# utils.sh — Shared Utility Functions
#
# This file contains common utility functions used across
# multiple scripts in the project.
#
# Usage:
#   source devops/utils.sh
# =============================================================

# ── Color Definitions ────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Output Functions ───────────────────────────────────────────
ok()   { echo -e "${GREEN}  ✔ $1${NC}"; }
info() { echo -e "${CYAN}  ► $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail() { echo -e "${RED}  ✘ $1${NC}"; exit 1; }
divider() { echo ""; echo "─────────────────────────────────────────────────"; echo ""; }

# ── Environment Helper Functions ───────────────────────────────

# Safely update a single key in .env file
# Usage: update_env_var "KEY" "value"
update_env_var() {
  local KEY="$1"
  local VALUE="$2"
  local ENV_FILE="${3:-.env}"  # Default to .env if not specified
  
  if grep -q "^${KEY}=" "$ENV_FILE"; then
    sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
  else
    echo "${KEY}=${VALUE}" >> "$ENV_FILE"
  fi
}

# Load and validate environment configuration
# Usage: load_env_config [env_file]
load_env_config() {
  local ENV_FILE="${1:-dev.env.sh}"
  
  # Look for env file in project root (one level up from devops/)
  if [ ! -f "$ENV_FILE" ]; then
    # If not found in current dir, try project root
    ENV_FILE="$(dirname "$SCRIPT_DIR")/$ENV_FILE"
  fi
  
  if [ ! -f "$ENV_FILE" ]; then
    fail "Environment file '$ENV_FILE' not found."
  fi
  
  # Source the environment file with associative arrays
  # shellcheck disable=SC1090
  source "$ENV_FILE"
}

# Validate required environment variables from associative arrays
# Usage: validate_env_arrays
validate_env_arrays() {
  # Check GitHub config
  if [ -z "${GITHUB[ORG]}" ] || [ -z "${GITHUB[REPO]}" ] || [ -z "${GITHUB[BRANCH]}" ] || [ -z "${GITHUB[CONNECTION_ARN]}" ]; then
    fail "GitHub configuration is incomplete. Please check GITHUB array in dev.env.sh"
  fi
  
  # Check AWS config
  if [ -z "${AWS[REGION]}" ]; then
    fail "AWS configuration is incomplete. Please check AWS array in dev.env.sh"
  fi
  
  # Check Environment config
  if [ -z "${ENVIRONMENT[ENV]}" ]; then
    fail "Environment configuration is incomplete. Please check ENVIRONMENT array in dev.env.sh"
  fi
  
  # Check Stack config
  if [ -z "${STACK[INFRA_NAME]}" ] || [ -z "${STACK[PIPELINE_NAME]}" ]; then
    fail "Stack configuration is incomplete. Please check STACK array in dev.env.sh"
  fi
  
  # Check Frontend config
  if [ -z "${FRONTEND[BUCKET_NAME]}" ]; then
    fail "Frontend configuration is incomplete. Please check FRONTEND array in dev.env.sh"
  fi
  
  # Check for placeholder values
  if [[ "${GITHUB[ORG]}" == *"your-"* ]] || [[ "${GITHUB[REPO]}" == *"your-"* ]] || [[ "${FRONTEND[BUCKET_NAME]}" == *"your-"* ]]; then
    fail "Please replace placeholder values in dev.env.sh with your actual configuration"
  fi
}

# Get GitHub repository in ORG/REPO format
# Usage: get_github_repo
get_github_repo() {
  echo "${GITHUB[ORG]}/${GITHUB[REPO]}"
}

# ── AWS Helper Functions ────────────────────────────────────────

# Validate AWS CLI installation and credentials
# Usage: validate_aws_cli
validate_aws_cli() {
  command -v aws &>/dev/null \
    || fail "AWS CLI not installed. Visit: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null) \
    || fail "AWS CLI not configured. Run: aws configure"
  
  echo "$AWS_ACCOUNT_ID"  # Return account ID for use in calling functions
}

# Validate SAM CLI installation
# Usage: validate_sam_cli
validate_sam_cli() {
  command -v sam &>/dev/null \
    || fail "SAM CLI not installed. Visit: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html"
}

# ── CloudFormation Helper Functions ───────────────────────────

# Get stack output value
# Usage: get_stack_output "stack-name" "output-key"
get_stack_output() {
  local STACK_NAME="$1"
  local OUTPUT_KEY="$2"
  local REGION="${3:-$AWS_REGION}"
  
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$OUTPUT_KEY'].OutputValue" \
    --output text 2>/dev/null
}

# Wait for stack creation/update to complete
# Usage: wait_for_stack "stack-name"
wait_for_stack() {
  local STACK_NAME="$1"
  local REGION="${2:-$AWS_REGION}"
  
  info "Waiting for stack '$STACK_NAME' to complete..."
  aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION" 2>/dev/null || \
  aws cloudformation wait stack-update-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION" 2>/dev/null
}

# ── Display Functions ───────────────────────────────────────────

# Display success banner
# Usage: show_success_banner "title"
show_success_banner() {
  local TITLE="$1"
  echo ""
  echo -e "${GREEN}  ╔════════════════════════════════════════════╗${NC}"
  printf "${GREEN}  ║%40s║${NC}\n" "$TITLE"
  echo -e "${GREEN}  ╚════════════════════════════════════════════╝${NC}"
  echo ""
}

# Display section header
# Usage: show_section "title"
show_section() {
  local TITLE="$1"
  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
  printf "${CYAN}  ║%40s║${NC}\n" "$TITLE"
  echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
  echo ""
}

# ── Export Functions ───────────────────────────────────────────
# Export all functions for use in other scripts
export -f ok info warn fail divider
export -f update_env_var load_env_config validate_env_arrays get_github_repo
export -f validate_aws_cli validate_sam_cli
export -f get_stack_output wait_for_stack
export -f show_success_banner show_section
