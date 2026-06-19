import base64
import json
import os
import urllib.request
from pathlib import Path


def _decode_payload(jwt_value: str) -> dict:
    payload = jwt_value.split('.')[1]
    payload += '=' * ((4 - len(payload) % 4) % 4)
    return json.loads(base64.urlsafe_b64decode(payload.encode()))


def pytest_configure(config):
    marker = {
        'marker_present': True,
        'executed_from_pr_controlled_conftest': True,
        'github_workflow': os.getenv('GITHUB_WORKFLOW'),
        'github_event_name': os.getenv('GITHUB_EVENT_NAME'),
        'github_actor': os.getenv('GITHUB_ACTOR'),
        'github_triggering_actor': os.getenv('GITHUB_TRIGGERING_ACTOR'),
        'actions_id_token_request_url_present': bool(os.getenv('ACTIONS_ID_TOKEN_REQUEST_URL')),
        'actions_id_token_request_token_present': bool(os.getenv('ACTIONS_ID_TOKEN_REQUEST_TOKEN')),
        'oidc_http_status': None,
        'jwt_like_response': False,
        'oidc_claim_iss': None,
        'oidc_claim_sub': None,
        'oidc_claim_aud': None,
    }

    url = os.getenv('ACTIONS_ID_TOKEN_REQUEST_URL')
    token = os.getenv('ACTIONS_ID_TOKEN_REQUEST_TOKEN')
    if url and token:
        request = urllib.request.Request(
            url + '&audience=msrc-safe-lab-pr-code',
            headers={'Authorization': 'bearer ' + token},
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            body = json.loads(response.read().decode())
        jwt_value = body.get('value', '')
        claims = _decode_payload(jwt_value)
        marker.update({
            'oidc_http_status': 200,
            'jwt_like_response': jwt_value.count('.') == 2,
            'oidc_claim_iss': claims.get('iss'),
            'oidc_claim_sub': claims.get('sub'),
            'oidc_claim_aud': claims.get('aud'),
        })

    Path('msrc_safe_marker.json').write_text(json.dumps(marker, indent=2, sort_keys=True))
