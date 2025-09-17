# LocalStack Runtime

Spin up a fully local AWS-compatible endpoint for Terraform and integration tests.

```bash
docker compose -f infra/localstack/docker-compose.yml up -d
```

Key ports:

- `4566` – LocalStack edge proxy (all AWS APIs)
- `4510-4559` – Service-specific ports for internal emulators

The compose file persists data to `infra/localstack/data/` so repeated Terraform runs can reuse state. Run the following to reset the environment:

```bash
docker compose -f infra/localstack/docker-compose.yml down -v
```

Credentials are seeded with `AWS_ACCESS_KEY_ID=test`, `AWS_SECRET_ACCESS_KEY=test`, and the `us-east-1` region which matches the Terraform defaults under `infra/terraform/`.
