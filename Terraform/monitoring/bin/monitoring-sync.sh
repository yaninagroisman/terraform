#!/bin/bash
# Main sync script of the monitoring host. Lives in S3 (Terraform/monitoring/bin/) and is downloaded
# by /usr/local/bin/monitoring-sync before every run, so changing it is just `terraform apply`.
# Runs every 5 minutes (monitoring-sync.timer):
#   1. pulls config from S3
#   2. refreshes the EKS token/CA for Prometheus and the Slack webhook for Alertmanager
#   3. renders prometheus.yml, 4. (re)starts the stack and reloads configs
# Variables BUCKET, CLUSTER, REGION, SLACK_SECRET come from /etc/monitoring/env.
set -euo pipefail
: "$BUCKET" "$CLUSTER" "$REGION" "$SLACK_SECRET"
BASE="${MONITORING_BASE:-/opt/monitoring}"
install -d "$BASE/config" "$BASE/rendered" -m 755
install -d "$BASE/secrets" -m 755

# 1. Configuration from S3 (uploaded by Terraform from Terraform/monitoring/)
aws s3 sync "s3://$BUCKET/" "$BASE/config/" --delete --only-show-errors --region "$REGION"

# Prometheus and Alertmanager run as nobody (65534)
install_secret() { # $1 = name in $BASE/secrets, $2 = mode; content is in $1.new
  chown 65534:65534 "$BASE/secrets/$1.new"
  chmod "$2" "$BASE/secrets/$1.new"
  mv "$BASE/secrets/$1.new" "$BASE/secrets/$1"
}

# 2a. EKS access for Prometheus: endpoint, CA and a short-lived token (valid 15 min, refreshed every 5)
ENDPOINT="https://cluster-not-ready.invalid"
if aws eks describe-cluster --name "$CLUSTER" --region "$REGION" > /tmp/cluster.json 2>/dev/null \
   && [ "$(jq -r .cluster.status /tmp/cluster.json)" = "ACTIVE" ]; then
  ENDPOINT=$(jq -r .cluster.endpoint /tmp/cluster.json)
  jq -r .cluster.certificateAuthority.data /tmp/cluster.json | base64 -d > "$BASE/secrets/eks-ca.crt.new"
  aws eks get-token --cluster-name "$CLUSTER" --region "$REGION" --output json \
    | jq -r .status.token > "$BASE/secrets/eks-token.new"
  install_secret eks-ca.crt 444
  install_secret eks-token 400
fi

# 2b. Slack webhook for Alertmanager (stored only in Secrets Manager, never in Git or S3)
if WEBHOOK=$(aws secretsmanager get-secret-value --secret-id "$SLACK_SECRET" --region "$REGION" \
               --query SecretString --output text 2>/dev/null) && [ -n "$WEBHOOK" ]; then
  printf '%s' "$WEBHOOK" > "$BASE/secrets/slack-webhook-url.new"
  install_secret slack-webhook-url 400
else
  echo "WARNING: cannot read secret $SLACK_SECRET, Slack notifications will not work" >&2
fi
unset WEBHOOK

# 3. Render prometheus.yml (the API endpoint changes with every new cluster)
sed "s|__EKS_ENDPOINT__|$ENDPOINT|g" "$BASE/config/prometheus.yml" > "$BASE/rendered/prometheus.yml.new"
mv "$BASE/rendered/prometheus.yml.new" "$BASE/rendered/prometheus.yml"
rm -rf "$BASE/rendered/rules" && cp -r "$BASE/config/rules" "$BASE/rendered/rules"

# 4. Start or update containers, then reload configs (cheap; picks up rule and route changes)
cd "$BASE/config"
docker compose up -d --remove-orphans
sleep 2
curl -fsS -X POST http://localhost:9090/-/reload >/dev/null 2>&1 || echo "WARNING: Prometheus reload failed" >&2
curl -fsS -X POST http://localhost:9093/-/reload >/dev/null 2>&1 || echo "WARNING: Alertmanager reload failed" >&2
