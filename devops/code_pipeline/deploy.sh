#!/bin/bash

# This script is called by the CloudFront Invalidation CodeBuild project.
# S3 upload is handled separately by the CodePipeline S3 Deploy action.

echo "Starting CloudFront Invalidation..."

DISTRIBUTION_ID=$CLOUDFRONT_DISTRIBUTION

if [ -z "$DISTRIBUTION_ID" ]; then
  echo "ERROR: CLOUDFRONT_DISTRIBUTION environment variable is not set."
  exit 1
fi

echo "Creating CloudFront invalidation for distribution: $DISTRIBUTION_ID"

aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

echo "CloudFront invalidation created successfully"