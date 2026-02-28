---
name: credential-vault
description: Manages the full secrets lifecycle across AWS services and CI/CD pipelines: storage, retrieval, rotation, and audit. Use this skill whenever secrets need to be stored, accessed, rotated, or reviewed; when a new service needs AWS credentials or API keys; or when a CI/CD pipeline needs secret injection for deployment. Activate when someone says "manage secrets", "store credentials", "rotate keys", "secrets manager", "inject secrets", "secure config", or when hardcoded credentials or `.env` files appear in code. Don't wait to be asked: if secrets appear anywhere outside a secrets manager, this skill applies immediately.
---

# Credential Vault

Secure secrets lifecycle for AWS services and CI/CD pipelines.

## Core principle

**Never store secret values in:**
- Source code (hardcoded strings).
- Config files committed to Git (`.env`, `config.yaml`).
- CI/CD pipeline definitions (inline values).
- Docker images (build args visible in layer history).
- Memory files, documentation, or logs.

**Always store secret references**: names, ARNs, paths: never values.

## AWS secret storage decision matrix

| Use case | Service | Format |
|----------|---------|--------|
| Database credentials | Secrets Manager | JSON key-value |
| API keys, tokens | Secrets Manager | JSON or plaintext |
| Feature flags, config | SSM Parameter Store | String/SecureString |
| Encryption keys | KMS | Key ARN reference |
| Service-to-service auth | IAM roles (no secrets needed) | Role ARN |
| CI/CD AWS access | OIDC federation (no secrets needed) | Role ARN |

### Secrets Manager vs SSM Parameter Store

| Feature | Secrets Manager | SSM Parameter Store |
|---------|----------------|-------------------|
| Auto-rotation | Yes (Lambda-backed) | No (manual) |
| Cross-account access | Yes (resource policy) | Limited |
| Cost | $0.40/secret/month + $0.05/10K API calls | Free (standard) / $0.05/advanced |
| Max size | 64KB | 8KB (standard) / 8KB (advanced) |
| Best for | Credentials, tokens, certs | Config values, feature flags |

## Secret naming conventions

```
/<environment>/<service>/<secret-name>

Examples:
/prod/payment-service/stripe-api-key
/staging/data-pipeline/redshift-credentials
/prod/auth-service/jwt-signing-key
```

- Use consistent prefix hierarchy for IAM policy scoping.
- Never include secret values in the name.

## Runtime access patterns

### Python (boto3)

```python
import json
import boto3
from functools import lru_cache

@lru_cache(maxsize=1)
def get_secret(secret_name: str, region: str = "us-east-1") -> dict:
    """Retrieve and cache secret from Secrets Manager."""
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

# Usage
db_creds = get_secret("/prod/my-service/db-credentials")
connection_string = f"postgresql://{db_creds['username']}:{db_creds['password']}@{db_creds['host']}/{db_creds['database']}"
```

### Java (AWS SDK v2)

```java
SecretsManagerClient client = SecretsManagerClient.builder()
    .region(Region.US_EAST_1)
    .build();

GetSecretValueResponse response = client.getSecretValue(
    GetSecretValueRequest.builder().secretId(secretName).build()
);
String secretString = response.secretString();
```

### TypeScript (AWS SDK v3)

```typescript
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const client = new SecretsManagerClient({ region: "us-east-1" });

async function getSecret(secretName: string): Promise<Record<string, string>> {
  const response = await client.send(new GetSecretValueCommand({ SecretId: secretName }));
  return JSON.parse(response.SecretString!);
}
```

## CI/CD secret injection

### GitHub Actions (OIDC: preferred, no stored secrets)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-arn: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
      aws-region: us-east-1

  # Secrets are fetched at runtime from AWS, not stored in GitHub
  - run: |
      SECRET=$(aws secretsmanager get-secret-value --secret-id /prod/my-service/api-key --query SecretString --output text)
      echo "::add-mask::$SECRET"
      echo "API_KEY=$SECRET" >> $GITHUB_ENV
```

### GitHub Actions (repository secrets: fallback)

```yaml
env:
  API_KEY: ${{ secrets.API_KEY }}
```

- Use repository secrets for non-AWS secrets only.
- Use environment-scoped secrets for environment-specific values.
- Enable required reviewers on production environment.

### Bitbucket Pipelines

```yaml
# Use repository variables (secured)
script:
  - export API_KEY=$API_KEY  # Set as secured variable in Bitbucket settings

# For AWS: use OIDC (Bitbucket OpenID Connect)
- pipe: atlassian/aws-oidc-token:0.1.0
  variables:
    ROLE_ARN: $AWS_ROLE_ARN
```

### GitLab CI

```yaml
# Use CI/CD variables (masked + protected)
deploy:
  script:
    - echo "$API_KEY"  # Set as masked variable in GitLab CI/CD settings

# For AWS: use OIDC
  id_tokens:
    AWS_TOKEN:
      aud: https://gitlab.com
```

## Secret rotation

### Automated rotation (Secrets Manager)

```python
# Lambda rotation function pattern
def lambda_handler(event, context):
    step = event["Step"]
    secret_id = event["SecretId"]

    if step == "createSecret":
        # Generate new secret value
        pass
    elif step == "setSecret":
        # Apply new secret to target service (DB, API, etc.)
        pass
    elif step == "testSecret":
        # Verify new secret works
        pass
    elif step == "finishSecret":
        # Mark new version as AWSCURRENT
        pass
```

### Rotation schedule

| Secret type | Rotation frequency | Method |
|------------|-------------------|--------|
| Database passwords | 30-90 days | Automated Lambda rotation |
| API keys | 90 days | Manual or automated |
| IAM access keys | 90 days | Automated (prefer OIDC instead) |
| TLS certificates | 30 days before expiry | ACM auto-renewal |
| JWT signing keys | 180 days | Automated with key versioning |

## IAM least-privilege patterns

### Service role for secret access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:*:secret:/prod/my-service/*"
    }
  ]
}
```

- Scope to specific secret ARN prefix: never use `*` for resource.
- Separate read and rotate permissions.
- Use `Condition` keys for additional restrictions (VPC, source IP, time).

### OIDC trust policy (GitHub Actions)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:org/repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## Audit and compliance

- Enable CloudTrail logging for all Secrets Manager and SSM API calls.
- Set up CloudWatch Alarms for: `GetSecretValue` from unexpected principals, failed access attempts.
- Regularly audit: who has access, when secrets were last rotated, which secrets are unused.
- Use AWS Config rules: `secretsmanager-rotation-enabled-check`, `secretsmanager-scheduled-rotation-success-check`.

## Rules

- Never log secret values: mask in CI output (`::add-mask::` in GitHub Actions). Logs are stored, indexed, and often visible to many people; a logged secret is a rotated secret.
- Never pass secrets as CLI arguments: they appear in the process list (`ps aux`) and shell history, both of which are frequently readable by other processes.
- Never commit `.env` files with real values: use `.env.example` with placeholder names. Git history is permanent and repos get cloned widely.
- Prefer OIDC federation over stored AWS credentials in CI/CD: OIDC tokens are short-lived and scoped; stored keys are long-lived and rotate awkwardly.
- Prefer IAM roles over access keys for service-to-service auth: roles rotate automatically and don't appear in config files.
- Secrets Manager and SSM SecureString encrypt at rest by default: don't implement custom encryption on top; it adds complexity without benefit.
- Separate secrets by environment: sharing prod secrets with dev/staging means a dev environment breach exposes production credentials.

## Edge cases

- **Local development:** use `.env.local` (gitignored) or AWS SSO profile; never copy prod secrets locally.
- **Multi-account:** use cross-account resource policies on Secrets Manager; or replicate secrets per account.
- **Lambda cold start + secret fetch:** cache secret outside handler scope; refresh on rotation interval.
- **Secret too large (>64KB):** split into multiple secrets or store in S3 with encryption.
- **Rotation failure:** configure DLQ on rotation Lambda; alert on failed rotation; secret stays on current version.
- **Emergency secret revocation:** update secret value immediately; downstream services will get new value on next fetch (respect caching TTL).
- **Developers needing prod secrets for debugging:** use temporary assume-role with MFA; audit all access; revoke after use.
- **Monorepo with multiple services:** scope secret paths per service (`/prod/<service-a>/`, `/prod/<service-b>/`); separate IAM policies.
