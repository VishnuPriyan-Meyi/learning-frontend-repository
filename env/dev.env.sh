#!/bin/bash

# =============================================================
# dev.env.sh — Frontend Pipeline Configuration
# =============================================================

# ── GitHub Config Object ───────────────────────────────────────
GITHUB=(
  [ORG]="VishnuPriyan-Meyi"
  [REPO]="learning-frontend-repository"
  [BRANCH]="feature/frontend-sam-pipeline"
  [CONNECTION_ARN]="arn:aws:codeconnections:us-east-1:369606757523:connection/f2bea9f7-7d24-488f-a22f-dd79bc071c10"
)

# ── AWS Config Object ──────────────────────────────────────────
AWS=(
  [REGION]="us-east-1"
)

# ── Environment Config Object ───────────────────────────────────
ENVIRONMENT=(
  [ENV]="dev"
)

# ── Stack Config Object ────────────────────────────────────────
STACK=(
  [INFRA_NAME]="frontend-infra"
  [PIPELINE_NAME]="react-dev-frontend-pipeline"
)

# ── Frontend Config Object ─────────────────────────────────────
FRONTEND=(
  [BUCKET_NAME]="react-dev-frontend-bucket"
)

# ── Bootstrap Config Object ────────────────────────────────────
BOOTSTRAP=(
  [STACK_NAME]="shared-${ENVIRONMENT[ENV]}-artifact-bootstrap"
  [BUCKET_NAME]="shared-${ENVIRONMENT[ENV]}-artifact-bucket"
  [FRONTEND_PREFIX]="frontend"
)
