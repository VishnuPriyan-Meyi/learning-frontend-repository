#!/bin/bash

# =============================================================
# setup.sh — Fully Automated Setup Script (SAM)
#
# Run this ONCE before anything else. It will:
#
#   1.  Validate prerequisites via init.sh
#   2.  Deploy frontend_template.yaml using SAM → creates S3 + CloudFront
#   3.  Fetch outputs → auto-fill .env
#   4.  Deploy pipeline.yaml using SAM → creates IAM roles, CodeBuild
#       projects, GitHub connection, and the pipeline (all in
#       one CloudFormation stack)
#   5.  Poll until you complete GitHub OAuth in the browser
#
# Usage (Git Bash or WSL on Windows):
#   chmod +x devops/setup.sh
#   ./devops/setup.sh
# =============================================================

set -e  # Exit on any error

# ── Load utility functions ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ── Load prerequisites validation ─────────────────────────────
source "$SCRIPT_DIR/init.sh"

# ── Run prerequisites validation ───────────────────────────────
validate_prerequisites

# ── Load configuration from .env ─────────────────────────────
load_env_config

# ──────────────────────────────────────────────────────────────

# ── Step 1: Deploy Infrastructure (CloudFront) with SAM ────
echo "[ Step 1 ] Deploying infrastructure stack: ${STACK[INFRA_NAME]}"
info "This creates your S3 bucket and CloudFront distribution using SAM..."

sam deploy \
  --template-file devops/template_file/frontend_template.yaml \
  --stack-name "${STACK[INFRA_NAME]}" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    BootstrapStackName="${BOOTSTRAP[STACK_NAME]}" \
    CloudFrontDistribution="${STACK[INFRA_NAME]}" \
  --region "${AWS[REGION]}"

ok "Infrastructure stack deployed."
divider

# ── Step 2: Fetch Outputs + Update .env ──────────────────────
echo "[ Step 2 ] Fetching stack outputs..."

STACK_BUCKET=$(get_stack_output "${STACK[INFRA_NAME]}" "BucketName" "${AWS[REGION]}")
CLOUDFRONT_URL=$(get_stack_output "${STACK[INFRA_NAME]}" "CloudFrontURL" "${AWS[REGION]}")
CLOUDFRONT_DOMAIN=$(echo "$CLOUDFRONT_URL" | sed 's|https://||')
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='$CLOUDFRONT_DOMAIN'].Id" \
  --output text)

ok "S3 Bucket:           $STACK_BUCKET"
ok "CloudFront URL:      $CLOUDFRONT_URL"
ok "CloudFront Dist. ID: $DISTRIBUTION_ID"

ok "Infrastructure deployed successfully."
divider

# ── Step 3: Deploy Pipeline Stack with SAM ─────────────────────
echo "[ Step 3 ] Deploying pipeline stack: ${STACK[PIPELINE_NAME]}"
info "This creates IAM roles, CodeBuild projects, GitHub connection, and the pipeline using SAM..."

sam deploy \
  --template-file devops/code_pipeline/pipeline.yaml \
  --stack-name "${STACK[PIPELINE_NAME]}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BootstrapStackName="${BOOTSTRAP[STACK_NAME]}" \
    GitHubOrgRepo="$(get_github_repo)" \
    GitHubBranch="${GITHUB[BRANCH]}" \
    FrontendBucketName="$STACK_BUCKET" \
    CloudFrontDistributionId="$DISTRIBUTION_ID" \
    GitHubConnectionArn="${GITHUB[CONNECTION_ARN]}" \
  --region "${AWS[REGION]}"

ok "Pipeline stack deployed using SAM."
divider

# ── Done ─────────────────────────────────────────────────────
show_success_banner "SAM Setup Complete! 🎉"
echo "  S3 Bucket:       $STACK_BUCKET"
echo "  CloudFront URL:  $CLOUDFRONT_URL"
echo "  Pipeline Stack:  ${STACK[PIPELINE_NAME]}"
echo ""
info "Push your code to trigger the pipeline:"
echo ""
echo "    git add ."
echo "    git commit -m \"initial deploy with SAM\""
echo "    git push origin ${GITHUB[BRANCH]}"
echo ""
echo "  Monitor pipeline:"
echo "  https://${AWS[REGION]}.console.aws.amazon.com/codesuite/codepipeline/pipelines"
echo ""
