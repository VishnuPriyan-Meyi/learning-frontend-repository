set -e  # Exit on any error

SKIP_VALIDATION=false
if [ "$1" = "--skip-validation" ]; then
  SKIP_VALIDATION=true
  echo "Skipping AWS CLI validation for redeployment..."
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
# Declare associative arrays in main script scope before calling function
declare -A GITHUB AWS ENVIRONMENT STACK FRONTEND BOOTSTRAP

load_env_config

# ──────────────────────────────────────────────────────────────

# ── Step 1: Deploy Pipeline Stack with SAM ─────────────────────
echo "[ Step 1 ] Deploying pipeline stack: ${STACK[PIPELINE_NAME]}"
info "This creates IAM roles, CodeBuild projects, GitHub connection, and the pipeline using SAM..."

# Use actual bucket name from environment config for pipeline deployment
sam deploy \
  --template-file "$SCRIPT_DIR/code_pipeline/pipeline.yaml" \
  --stack-name "${STACK[PIPELINE_NAME]}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BootstrapStackName="${BOOTSTRAP[STACK_NAME]}" \
    GitHubOrgRepo="$(get_github_repo)" \
    GitHubBranch="${GITHUB[BRANCH]}" \
    FrontendBucketName="${FRONTEND[BUCKET_NAME]}" \
    CloudFrontDistributionId="PLACEHOLDER_DISTRIBUTION_ID" \
    GitHubConnectionArn="${GITHUB[CONNECTION_ARN]}" \
    ArtifactsBucketName="${BOOTSTRAP[BUCKET_NAME]}" \
  --region "${AWS[REGION]}"

ok "Pipeline stack deployed using SAM."
divider

# ── Step 2: Deploy Infrastructure (CloudFront) with SAM ────
echo "[ Step 2 ] Deploying infrastructure stack: ${STACK[INFRA_NAME]}"
info "This creates your S3 bucket and CloudFront distribution using SAM..."

sam deploy \
  --template-file "$SCRIPT_DIR/template_file/frontend_template.yaml" \
  --stack-name "${STACK[INFRA_NAME]}" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    BootstrapStackName="${BOOTSTRAP[STACK_NAME]}" \
    CloudFrontDistribution="${STACK[INFRA_NAME]}" \
    FrontendBucketName="${FRONTEND[BUCKET_NAME]}" \
    AWSRegion="${AWS[REGION]}" \
  --region "${AWS[REGION]}"

ok "Infrastructure stack deployed."
divider

# ── Step 3: Fetch Outputs + Update Pipeline ─────────────────
echo "[ Step 3 ] Fetching stack outputs..."

STACK_BUCKET=$(get_stack_output "${STACK[INFRA_NAME]}" "BucketName" "${AWS[REGION]}")
CLOUDFRONT_URL=$(get_stack_output "${STACK[INFRA_NAME]}" "CloudFrontURL" "${AWS[REGION]}")
CLOUDFRONT_DOMAIN=$(echo "$CLOUDFRONT_URL" | sed 's|https://||')
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='$CLOUDFRONT_DOMAIN'].Id" \
  --output text)

ok "S3 Bucket:           $STACK_BUCKET"
ok "CloudFront URL:      $CLOUDFRONT_URL"
ok "CloudFront Dist. ID: $DISTRIBUTION_ID"

# Update pipeline with correct CloudFront distribution ID
echo "[ Step 4 ] Updating pipeline with correct CloudFront distribution ID..."
sam deploy \
  --template-file "$SCRIPT_DIR/code_pipeline/pipeline.yaml" \
  --stack-name "${STACK[PIPELINE_NAME]}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    BootstrapStackName="${BOOTSTRAP[STACK_NAME]}" \
    GitHubOrgRepo="$(get_github_repo)" \
    GitHubBranch="${GITHUB[BRANCH]}" \
    FrontendBucketName="${STACK_BUCKET}" \
    CloudFrontDistributionId="${DISTRIBUTION_ID}" \
    GitHubConnectionArn="${GITHUB[CONNECTION_ARN]}" \
    ArtifactsBucketName="${BOOTSTRAP[BUCKET_NAME]}" \
  --region "${AWS[REGION]}"

ok "Pipeline updated with correct CloudFront distribution ID."
divider

ok "Infrastructure deployed successfully."

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
