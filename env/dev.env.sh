#!/bin/bash

# =============================================================
# dev.env.sh — Frontend Pipeline Configuration
# =============================================================

# ── GitHub Config Object ───────────────────────────────────────
declare -A GITHUB=(
  [ORG]="VishnuPriyan-Meyi"
  [REPO]="learning-frontend-repository"
  [BRANCH]="feature/frontend-sam-pipeline"
  [CONNECTION_ARN]="arn:aws:codeconnections:us-east-1:369606757523:connection/f2bea9f7-7d24-488f-a22f-dd79bc071c10"
)

# ── AWS Config Object ──────────────────────────────────────────
declare -A AWS=(
  [REGION]="us-east-1"
)

# ── Environment Config Object ───────────────────────────────────
declare -A ENVIRONMENT=(
  [ENV]="dev"
)

# ── Stack Config Object ────────────────────────────────────────
declare -A STACK=(
  [INFRA_NAME]="frontend-infra"
  [PIPELINE_NAME]="react-dev-frontend-pipeline"
)

# ── Frontend Config Object ─────────────────────────────────────
declare -A FRONTEND=(
  [BUCKET_NAME]="react-dev-frontend-bucket"
)

# ── Bootstrap Config Object ────────────────────────────────────
declare -A BOOTSTRAP=(
  [STACK_NAME]="shared-${ENVIRONMENT[ENV]}-artifact-bootstrap"
  [BUCKET_NAME]="shared-${ENVIRONMENT[ENV]}-artifact-bucket"
  [FRONTEND_PREFIX]="frontend"
)