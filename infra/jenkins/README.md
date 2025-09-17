# Jenkins-in-Docker Controller

This image runs Jenkins with all the tooling needed to manage the SRE Lab locally: Docker CLI, Kind, kubectl, Terraform, yq, and jq. The accompanying compose file binds the repo into the container so jobs operate on the same workspace you use manually.

## Usage

```bash
docker compose -f infra/jenkins/docker-compose.yml up -d --build
```

Once Jenkins is up, browse to `http://localhost:8080`.

- Default admin user/password: the container uses the standard Jenkins setup flow, so grab the initial admin password from the container logs if you want to complete the classic wizard.
- Install the Docker, Git, and Pipeline plugins (plus anything else you need).

### Jenkins agent considerations

All pipeline steps execute inside the controller container. Because the compose stack mounts the Docker socket, Jenkins can run `docker`, `kind`, and `kubectl` commands directly against your host. Terraform also works using the LocalStack endpoint on the host.

### Shutdown

```bash
docker compose -f infra/jenkins/docker-compose.yml down
```

Persisted Jenkins state lives in the named volume `jenkins_home`.
