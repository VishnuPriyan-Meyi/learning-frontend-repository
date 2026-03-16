#!/bin/bash

# =============================================================
# setup.sh — Fully Automated Prerequisites Setup Script
#
# Run this ONCE before anything else. It will:
#
#   1.  Validate AWS CLI + credentials
#   2.  Deploy frontend_template.yaml → creates S3 + CloudFront
#   3.  Fetch outputs → auto-fill .env
#   4.  Deploy pipeline.yaml → creates IAM roles, CodeBuild
#       projects, GitHub connection, and the pipeline (all in
#       one CloudFormation stack)
#   5.  Poll until you complete GitHub OAuth in the browser
#
# Usage (Git Bash or WSL on Windows):
#   chmod +x devops/setup.sh
#   ./devops/setup.sh
# =============================================================

set -e  # Exit on any error

# ── Load configuration from .env ─────────────────────────────
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found in the repo root."
  exit 1
fi

# Export all variables from .env (strip comments and blank lines)
set -a
# shellcheck disable=SC1090
source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$' | sed 's/[[:space:]]*#.*//')
set +a

# Validate required config vars are filled in
REQUIRED_VARS=(GITHUB_ORG_REPO GITHUB_BRANCH BUCKET_NAME
               INFRA_STACK_NAME PIPELINE_STACK_NAME AWS_REGION)

for VAR in "${REQUIRED_VARS[@]}"; do
  VALUE="${!VAR}"
  if [ -z "$VALUE" ] || [[ "$VALUE" == *"ORG/REPO"* ]]; then
    echo "ERROR: '$VAR' is not set in .env. Please fill in all config values."
    exit 1
  fi
done

# ── Helper: safely update a single key in .env ───────────────
update_env_var() {
  local KEY="$1"
  local VALUE="$2"
  if grep -q "^${KEY}=" "$ENV_FILE"; then
    sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
  else
    echo "${KEY}=${VALUE}" >> "$ENV_FILE"
  fi
}

# ── Colours ───────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✔ $1${NC}"; }
info() { echo -e "${CYAN}  ► $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail() { echo -e "${RED}  ✘ $1${NC}"; exit 1; }
divider() { echo ""; echo "─────────────────────────────────────────────────"; echo ""; }

# ──────────────────────────────────────────────────────────────

# ── Step 1: Validate AWS CLI ─────────────────────────────────
echo "[ Step 1 ] Validating AWS CLI..."

command -v aws &>/dev/null \
  || fail "AWS CLI not installed. Visit: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null) \
  || fail "AWS CLI not configured. Run: aws configure"

ok "AWS CLI OK. Account: $AWS_ACCOUNT_ID | Region: $AWS_REGION"
divider

# ── Step 2: Deploy Infrastructure (S3 + CloudFront) ──────────
echo "[ Step 2 ] Deploying infrastructure stack: $INFRA_STACK_NAME"
info "This creates your S3 bucket and CloudFront distribution..."

aws cloudformation deploy \
  --template-file devops/template_file/frontend_template.yaml \
  --stack-name "$INFRA_STACK_NAME" \
  --parameter-overrides BucketName="$BUCKET_NAME" \
  --region "$AWS_REGION"

ok "Infrastructure stack deployed."
divider

# ── Step 3: Fetch Outputs + Update .env ──────────────────────
echo "[ Step 3 ] Fetching stack outputs..."

STACK_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$INFRA_STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
  --output text)

CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
  --stack-name "$INFRA_STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontURL'].OutputValue" \
  --output text)

CLOUDFRONT_DOMAIN=$(echo "$CLOUDFRONT_URL" | sed 's|https://||')
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='$CLOUDFRONT_DOMAIN'].Id" \
  --output text)

ok "S3 Bucket:           $STACK_BUCKET"
ok "CloudFront URL:      $CLOUDFRONT_URL"
ok "CloudFront Dist. ID: $DISTRIBUTION_ID"

info "Updating .env with auto-filled values..."
update_env_var "S3_BUCKET" "$STACK_BUCKET"
update_env_var "CLOUDFRONT_DISTRIBUTION" "$DISTRIBUTION_ID"
ok ".env updated."
divider

# ── Step 4: Deploy Pipeline Stack ────────────────────────────
# pipeline.yaml defines EVERYTHING in one CloudFormation stack:
#   - IAM roles (CodePipelineRole, CodeBuildRole)
#   - Artifacts S3 bucket
#   - GitHub CodeStar connection
#   - CodeBuild projects (react-build + cloudfront-invalidation)
#   - The CodePipeline itself
echo "[ Step 4 ] Deploying pipeline stack: $PIPELINE_STACK_NAME"
info "This creates IAM roles, CodeBuild projects, GitHub connection, and the pipeline..."

aws cloudformation deploy \
  --template-file devops/code_pipeline/pipeline.yaml \
  --stack-name "$PIPELINE_STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubOrgRepo="$GITHUB_ORG_REPO" \
    GitHubBranch="$GITHUB_BRANCH" \
    FrontendBucketName="$STACK_BUCKET" \
    CloudFrontDistributionId="$DISTRIBUTION_ID" \
  --region "$AWS_REGION"

ok "Pipeline stack deployed."
divider

# ── Step 5: Wait for GitHub OAuth ────────────────────────────
echo "[ Step 5 ] Activating GitHub connection..."

# Get the connection ARN from the stack output
CONNECTION_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$PIPELINE_STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='GitHubConnectionArn'].OutputValue" \
  --output text)

CONNECTION_STATUS=$(aws codestar-connections get-connection \
  --connection-arn "$CONNECTION_ARN" \
  --query "Connection.ConnectionStatus" \
  --output text)

if [ "$CONNECTION_STATUS" != "AVAILABLE" ]; then
  echo ""
  echo -e "${YELLOW}  ┌────────────────────────────────────────────────────────┐${NC}"
  echo -e "${YELLOW}  │   ACTION REQUIRED — Authorize GitHub in your browser   │${NC}"
  echo -e "${YELLOW}  │                                                        │${NC}"
  echo -e "${YELLOW}  │  1. Open:                                              │${NC}"
  echo -e "${YELLOW}  │     https://${AWS_REGION}.console.aws.amazon.com/      │${NC}"
  echo -e "${YELLOW}  │     codesuite/settings/connections                    │${NC}"
  echo -e "${YELLOW}  │  2. Find: github-frontend-connection                  │${NC}"
  echo -e "${YELLOW}  │  3. Click \"Update pending connection\"                  │${NC}"
  echo -e "${YELLOW}  │  4. Authorize with your GitHub account                │${NC}"
  echo -e "${YELLOW}  └────────────────────────────────────────────────────────┘${NC}"
  echo ""
  info "Polling every 10 seconds until authorized..."

  while true; do
    sleep 10
    STATUS=$(aws codestar-connections get-connection \
      --connection-arn "$CONNECTION_ARN" \
      --query "Connection.ConnectionStatus" \
      --output text)
    if [ "$STATUS" == "AVAILABLE" ]; then
      ok "GitHub connection is now AVAILABLE!"
      break
    fi
    info "Still waiting... (status: $STATUS)"
  done
else
  ok "GitHub connection is already AVAILABLE."
fi
divider

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║         Setup Complete! 🎉                 ║${NC}"
echo -e "${GREEN}  ╚════════════════════════════════════════════╝${NC}"
echo ""
echo "  S3 Bucket:       $STACK_BUCKET"
echo "  CloudFront URL:  $CLOUDFRONT_URL"
echo "  Pipeline Stack:  $PIPELINE_STACK_NAME"
echo ""
echo -e "${CYAN}  Push your code to trigger the pipeline:${NC}"
echo ""
echo "    git add ."
echo "    git commit -m \"initial deploy\""
echo "    git push origin $GITHUB_BRANCH"
echo ""
echo "  Monitor pipeline:"
echo "  https://$AWS_REGION.console.aws.amazon.com/codesuite/codepipeline/pipelines"
echo ""
