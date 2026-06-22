#!/usr/bin/env bash
set -euo pipefail

mkdir -p proof
proof_file="proof/owned-replica-proof.txt"
account_json="proof/account-redacted.json"
canary_json="proof/canary-redacted.json"
rg_canary="false"
rg_name=""

hash_value() {
  local value="${1:-}"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "absent"
  else
    printf '%s' "$value" | sha256sum | cut -d' ' -f1
  fi
}

{
  echo "marker=true"
  echo "marker_source_sha=${GITHUB_SHA:-unknown}"
  echo "github_event=${GITHUB_EVENT_NAME:-unknown}"
  echo "github_ref=${GITHUB_REF:-unknown}"
  echo "github_head_ref=${GITHUB_HEAD_REF:-}"
  echo "github_base_ref=${GITHUB_BASE_REF:-}"
  echo "job_name=${GITHUB_JOB:-unknown}"
  echo "runner_name=${RUNNER_NAME:-unknown}"
  echo "runner_os=${RUNNER_OS:-unknown}"
  echo "runner_arch=${RUNNER_ARCH:-unknown}"
  echo "login_outcome=${LOGIN_OUTCOME:-unknown}"
  echo "login_conclusion=${LOGIN_CONCLUSION:-unknown}"
  echo "execution_phase=post_auth_step"
} > "$proof_file"

if [[ "${LOGIN_OUTCOME:-}" != "success" ]]; then
  {
    echo "managed_identity_or_oidc_login_success=false"
    echo "post_auth_azure_capability_attempted=false"
  } >> "$proof_file"
  exit 0
fi

if ! az account show --query '{tenantId:tenantId, subscriptionId:id, accountType:user.type}' -o json > "$account_json"; then
  {
    echo "az_account_show_success=false"
    echo "post_auth_azure_capability_attempted=false"
  } >> "$proof_file"
  exit 0
fi

tenant_id="$(jq -r '.tenantId // empty' "$account_json")"
subscription_id="$(jq -r '.subscriptionId // empty' "$account_json")"
account_type="$(jq -r '.accountType // "unknown"' "$account_json")"

{
  echo "managed_identity_or_oidc_login_success=true"
  echo "az_account_show_success=true"
  echo "account_type=${account_type}"
  echo "tenant_hash=sha256:$(hash_value "$tenant_id")"
  echo "subscription_hash=sha256:$(hash_value "$subscription_id")"
} >> "$proof_file"

if [[ -z "${CANARY_RESOURCE_ID:-}" ]]; then
  {
    echo "canary_resource_configured=false"
    echo "canary_read_success=false"
    echo "canary_write_attempted=false"
  } >> "$proof_file"
  exit 0
fi

resource_hash="$(hash_value "$CANARY_RESOURCE_ID")"
echo "canary_resource_hash=sha256:${resource_hash}" >> "$proof_file"

if [[ "$CANARY_RESOURCE_ID" =~ /resourceGroups/([^/]+)$ ]]; then
  rg_canary="true"
  rg_name="${BASH_REMATCH[1]}"
fi

if [[ "$rg_canary" == "true" ]] && az group show --name "$rg_name" --query '{id:id,type:type,tags:tags}' -o json > "$canary_json"; then
  canary_type="Microsoft.Resources/resourceGroups"
  echo "canary_read_success=true" >> "$proof_file"
  echo "canary_resource_type=${canary_type}" >> "$proof_file"
elif az resource show --ids "$CANARY_RESOURCE_ID" --query '{id:id,type:type,tags:tags}' -o json > "$canary_json"; then
  canary_type="$(jq -r '.type // "unknown"' "$canary_json")"
  echo "canary_read_success=true" >> "$proof_file"
  echo "canary_resource_type=${canary_type}" >> "$proof_file"
else
  echo "canary_read_success=false" >> "$proof_file"
  echo "canary_write_attempted=false" >> "$proof_file"
  exit 0
fi

if [[ "${CANARY_WRITE_ENABLED:-false}" != "true" ]]; then
  echo "canary_write_attempted=false" >> "$proof_file"
  exit 0
fi

original_tags="$(jq -c '.tags // {}' "$canary_json")"
marker_value="owned-replica-${GITHUB_RUN_ID:-unknown}-${GITHUB_RUN_ATTEMPT:-0}"

if [[ "$rg_canary" == "true" ]]; then
  az group update --name "$rg_name" --set tags.msrc-owned-replica="$marker_value" --output none
else
  az resource tag --ids "$CANARY_RESOURCE_ID" --tags msrc-owned-replica="$marker_value" --output none
fi
echo "canary_write_attempted=true" >> "$proof_file"
echo "canary_write_success=true" >> "$proof_file"

if [[ "$original_tags" == "{}" ]]; then
  if [[ "$rg_canary" == "true" ]]; then
    az group update --name "$rg_name" --set tags={} --output none
  else
    az resource tag --ids "$CANARY_RESOURCE_ID" --tags '{}' --output none
  fi
else
  tmp_tags="proof/original-tags.json"
  printf '%s' "$original_tags" > "$tmp_tags"
  if [[ "$rg_canary" == "true" ]]; then
    az group update --name "$rg_name" --set tags=@"$tmp_tags" --output none
  else
    az resource tag --ids "$CANARY_RESOURCE_ID" --tags @"$tmp_tags" --output none
  fi
fi

if [[ "$rg_canary" == "true" ]]; then
  az group show --name "$rg_name" --query 'tags' -o json > proof/restored-tags.json
else
  az resource show --ids "$CANARY_RESOURCE_ID" --query 'tags' -o json > proof/restored-tags.json
fi
restored_compact="$(jq -c '.' proof/restored-tags.json)"
restored_hash="$(hash_value "$restored_compact")"
original_hash="$(hash_value "$original_tags")"

if [[ "$restored_hash" == "$original_hash" ]]; then
  echo "restoration_verified=true" >> "$proof_file"
else
  echo "restoration_verified=false" >> "$proof_file"
fi
