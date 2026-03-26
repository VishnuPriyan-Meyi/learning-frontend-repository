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
#   ./devops/setup.sh --skip-validation  # Skip AWS CLI validation (for redeployment)
#   ./devops/setup.sh --pipeline-only   # Deploy pipeline only (skip frontend infra)
# =============================================================

set -e  # Exit on any error

SKIP_VALIDATION=false
SKIP_FRONTEND=false
if [ "$1" = "--skip-validation" ]; then
  SKIP_VALIDATION=true
  echo "Skipping AWS CLI validation for redeployment..."
fi
if [ "$1" = "--pipeline-only" ]; then
  SKIP_FRONTEND=true
  SKIP_VALIDATION=true
  echo "Pipeline-only deployment: skipping frontend template deployment and validation..."
fi

# ── Load utility functions ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
source "$SCRIPT_DIR/utils.sh"

# ── Load prerequisites validation ─────────────────────────────
source "$SCRIPT_DIR/init.sh"

# ── Run prerequisites validation ───────────────────────────────
validate_prerequisites

# ── Load configuration from .env ─────────────────────────────
load_env_config

# ──────────────────────────────────────────────────────────────

# ── Step 1: Deploy Infrastructure (CloudFront) with SAM ────
if [ "$SKIP_FRONTEND" = "false" ]; then
  echo "[ Step 1 ] Deploying infrastructure stack: $STACK_INFRA_NAME"
  info "This creates your S3 bucket and CloudFront distribution using SAM..."

  sam deploy \
    --template-file "$SCRIPT_DIR/template_file/frontend_template.yaml" \
    --stack-name "$STACK_INFRA_NAME" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      BootstrapStackName="$BOOTSTRAP_STACK_NAME" \
      CloudFrontDistribution="$STACK_INFRA_NAME" \
      SharedBucketName="$BOOTSTRAP_BUCKET_NAME" \
      AWSRegion="$AWS_REGION" \
    --region "$AWS_REGION"

  ok "Infrastructure stack deployed."
  divider
else
  echo "[ Step 1 ] Skipping frontend infrastructure deployment (pipeline-only mode)"
  divider
fi

# ── Step 2: Fetch Outputs + Update .env ──────────────────────
if [ "$SKIP_FRONTEND" = "false" ]; then
  echo "[ Step 2 ] Fetching stack outputs..."

  STACK_BUCKET=$(get_stack_output "$STACK_INFRA_NAME" "BucketName" "$AWS_REGION")
  CLOUDFRONT_URL=$(get_stack_output "$STACK_INFRA_NAME" "CloudFrontURL" "$AWS_REGION")
  CLOUDFRONT_DOMAIN=$(echo "$CLOUDFRONT_URL" | sed 's|https://||')
  DISTRIBUTION_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?DomainName=='$CLOUDFRONT_DOMAIN'].Id" \
    --output text)

  ok "Stack outputs fetched."
  divider
else
  echo "[ Step 2 ] Using existing infrastructure (pipeline-only mode)"
  # Set existing values for pipeline deployment
  STACK_BUCKET="$BOOTSTRAP_BUCKET_NAME"
  CLOUDFRONT_URL="https://existing-frontend-distribution.cloudfront.net"
  DISTRIBUTION_ID="EXISTING_DISTRIBUTION_ID"
  divider
fi

ok "S3 Bucket:           $STACK_BUCKET"
ok "CloudFront URL:      $CLOUDFRONT_URL"
ok "CloudFront Dist. ID: $DISTRIBUTION_ID"

ok "Infrastructure deployed successfully."
divider

# ── Step 3: Deploy Pipeline Stack with SAM ─────────────────────
echo "[ Step 3 ] Deploying pipeline stack: $STACK_PIPELINE_NAME"
info "This creates IAM roles, CodeBuild projects, GitHub connection, and the pipeline using SAM..."

sam deploy \
  --template-file "$SCRIPT_DIR/code_pipeline/pipeline.yaml" \
  --stack-name "$STACK_PIPELINE_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BootstrapStackName="$BOOTSTRAP_STACK_NAME" \
    GitHubOrgRepo="$(get_github_repo)" \
    GitHubBranch="$GITHUB_BRANCH" \
    FrontendBucketName="$STACK_BUCKET" \
    CloudFrontDistributionId="$DISTRIBUTION_ID" \
    GitHubConnectionArn="$GITHUB_CONNECTION_ARN" \
    ArtifactsBucketName="$BOOTSTRAP_BUCKET_NAME" \
  --region "$AWS_REGION"

ok "Pipeline stack deployed using SAM."
divider

# ── Done ─────────────────────────────────────────────────────
show_success_banner "SAM Setup Complete! 🎉"
echo "  S3 Bucket:       $STACK_BUCKET"
echo "  CloudFront URL:  $CLOUDFRONT_URL"
echo "  Pipeline Stack:  $STACK_PIPELINE_NAME"
echo ""
info "Push your code to trigger the pipeline:"
echo ""
echo "    git add ."
echo "    git commit -m \"initial deploy with SAM\""
echo "    git push origin $GITHUB_BRANCH"
echo ""
echo "  Monitor pipeline:"
echo "  https://$AWS_REGION.console.aws.amazon.com/codesuite/codepipeline/pipelines"
echo ""
