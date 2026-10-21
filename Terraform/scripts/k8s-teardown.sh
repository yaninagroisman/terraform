#!/usr/bin/env bash
# Called by terraform_data.k8s_teardown (teardown.tf) during `terraform destroy`.
# Removes everything that Kubernetes controllers created in AWS, while the controllers still run.
set -euo pipefail

: "${REGION:?REGION is not set}"
: "${CLUSTER:?CLUSTER is not set}"
: "${APP_NAME:?APP_NAME is not set}"

log() { echo "[k8s-teardown] $*"; }

if ! aws eks describe-cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  log "cluster $CLUSTER not found, nothing to clean up"
  exit 0
fi

# Separate kubeconfig, so the user's ~/.kube/config is not touched
KUBECONFIG="$(mktemp)"
export KUBECONFIG
trap 'rm -f "$KUBECONFIG"' EXIT
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --kubeconfig "$KUBECONFIG" >/dev/null

# 1. Delete the Argo CD Application. Its finalizer makes Argo CD delete the Deployment, Service
#    and Ingress first; the controller then deletes the weather ALB.
#    A timeout here is not fatal: step 3 decides success by checking AWS directly.
if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
  log "deleting Argo CD application '$APP_NAME' (cascade)"
  kubectl -n argocd delete application "$APP_NAME" --ignore-not-found --wait=true --timeout=8m \
    || log "WARNING: application '$APP_NAME' still deleting, continuing"
fi

# 2. Delete every remaining Ingress (argocd-server and anything created by hand).
log "deleting remaining Ingress objects"
kubectl delete ingress --all --all-namespaces --ignore-not-found --wait=true --timeout=8m \
  || log "WARNING: some Ingress objects are still being deleted, continuing"

# 3. Wait until the controller has removed its load balancers and security groups.
count_lbs() {
  local n=0 arn owner
  for arn in $(aws elbv2 describe-load-balancers --region "$REGION" \
                 --query 'LoadBalancers[].LoadBalancerArn' --output text); do
    owner=$(aws elbv2 describe-tags --region "$REGION" --resource-arns "$arn" \
      --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster'].Value | [0]" --output text)
    [ "$owner" = "$CLUSTER" ] && n=$((n + 1))
  done
  echo "$n"
}
count_sgs() {
  aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=tag:elbv2.k8s.aws/cluster,Values=$CLUSTER" \
    --query 'length(SecurityGroups)' --output text
}

log "waiting for controller-managed load balancers and security groups to disappear"
for _ in $(seq 1 60); do
  lbs=$(count_lbs)
  sgs=$(count_sgs)
  if [ "$lbs" = "0" ] && [ "$sgs" = "0" ]; then
    log "load balancers and security groups are gone"
    # ExternalDNS (policy sync, interval 1m) needs one more loop to delete the DNS records
    log "waiting 70s for ExternalDNS to remove DNS records"
    sleep 70
    log "done"
    exit 0
  fi
  log "still present: $lbs load balancer(s), $sgs security group(s)"
  sleep 10
done

log "ERROR: controller-managed AWS resources still exist after 10 minutes" >&2
log "check: kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=50" >&2
exit 1
