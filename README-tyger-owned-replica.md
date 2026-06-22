# Tyger Owned Replica Proof Lab

This lab is for reporter-owned or MSRC-controlled validation only. It does not touch Microsoft infrastructure.

It tests the missing Tyger evidence chain safely:

```text
checkout PR-controlled tree
-> local Azure login action
-> Azure login succeeds or fails
-> PR-controlled post-auth marker
-> optional owned canary read/tag update/restore
```

Required GitHub secrets for OIDC mode:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- optional `CANARY_RESOURCE_ID`

For `IDENTITY` mode, use only a self-hosted runner hosted on an Azure VM with a managed identity assigned. Do not run `IDENTITY` mode on Microsoft infrastructure without explicit MSRC authorization.

Safe outputs:

- login success/failure
- account type
- tenant/subscription hashes
- canary resource hash and type
- canary operation success/failure
- restoration status

Never print tokens, raw tenant ID, raw subscription ID, client secrets, Azure CLI cache, or customer data.
