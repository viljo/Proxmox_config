# GitLab CI/CD Pipeline Templates

This directory contains reusable CI/CD pipeline templates for common workflows in the Proxmox infrastructure.

## Available Templates

### 1. Docker Image Building (`docker-build.gitlab-ci.yml`)

**Purpose**: Build, test, and push Docker images to GitLab Container Registry

**Features**:
- Build Docker images from Dockerfile
- Security scanning with Trivy
- Automatic tagging with commit SHA
- Push to `latest` tag on main branch
- Semantic version tagging for releases
- Cleanup of old build images

**Usage**:
```yaml
# .gitlab-ci.yml
include:
  - local: '/ci-templates/docker-build.gitlab-ci.yml'

# Customize variables
variables:
  IMAGE_NAME: ${CI_REGISTRY_IMAGE}/my-app
```

**Requirements**:
- Dockerfile in repository root
- Runner with Docker executor and `docker` tag
- GitLab Container Registry enabled

---

### 2. Ansible Role Testing (`ansible-role-test.gitlab-ci.yml`)

**Purpose**: Lint, test, and validate Ansible roles and playbooks

**Features**:
- YAML syntax validation with yamllint
- Ansible best practices checking with ansible-lint
- Playbook syntax verification
- Role structure validation
- Molecule testing support (optional)
- Security checks for exposed secrets
- Automatic documentation generation

**Usage**:
```yaml
# .gitlab-ci.yml
include:
  - local: '/ci-templates/ansible-role-test.gitlab-ci.yml'

# Customize Python/Ansible versions
variables:
  ANSIBLE_VERSION: "2.15"
  PYTHON_VERSION: "3.11"
```

**Requirements**:
- `.yamllint` configuration file (optional)
- Runner with Docker executor
- Ansible roles in `roles/` directory
- Playbooks in `playbooks/` directory

**Configuration Files**:

Create `.yamllint` in repository root:
```yaml
extends: default
rules:
  line-length:
    max: 120
    level: warning
  comments:
    min-spaces-from-content: 1
```

---

### 3. Deployment with Approval (`deployment-with-approval.gitlab-ci.yml`)

**Purpose**: Multi-stage deployment pipeline with manual approval gates

**Features**:
- Build and test stages
- Automated deployment to staging
- Health check verification
- Manual approval gate for production
- Production deployment with audit trail
- Rollback capability
- Success/failure notifications

**Usage**:
```yaml
# .gitlab-ci.yml
include:
  - local: '/ci-templates/deployment-with-approval.gitlab-ci.yml'

# Customize environment URLs
variables:
  STAGING_URL: https://staging.example.com
  PRODUCTION_URL: https://example.com
```

**Requirements**:
- Ansible playbooks for deployment (`playbooks/deploy.yml`)
- Rollback playbook (`playbooks/rollback.yml`)
- Inventory files (`inventory/staging`, `inventory/production`)
- SSH deployment key stored in GitLab CI/CD variable `DEPLOYMENT_SSH_KEY`
- Health check endpoint (`/health`) on deployed applications

**GitLab CI/CD Variables** (Settings → CI/CD → Variables):
```
DEPLOYMENT_SSH_KEY: [SSH private key for deployment]
```

---

## How to Use Templates

### Option 1: Include Template Directly

```yaml
# .gitlab-ci.yml
include:
  - local: '/ci-templates/docker-build.gitlab-ci.yml'
```

### Option 2: Include Multiple Templates

```yaml
# .gitlab-ci.yml
include:
  - local: '/ci-templates/docker-build.gitlab-ci.yml'
  - local: '/ci-templates/ansible-role-test.gitlab-ci.yml'

# Override or extend jobs
docker-build:
  before_script:
    - echo "Custom pre-build step"
    - !reference [docker-build, before_script]
```

### Option 3: Extend Template Jobs

```yaml
# .gitlab-ci.yml
include:
  - local: '/ci-templates/deployment-with-approval.gitlab-ci.yml'

# Extend specific jobs
deploy-production:
  script:
    - echo "Additional production deployment steps"
    - ansible-playbook playbooks/notify-slack.yml
```

---

## Complete Example: Infrastructure Repository

```yaml
# .gitlab-ci.yml for Proxmox_config repository
---
include:
  - local: '/ci-templates/ansible-role-test.gitlab-ci.yml'

variables:
  ANSIBLE_VERSION: "2.15"
  PYTHON_VERSION: "3.11"

stages:
  - lint
  - test
  - validate
  - deploy

# Add custom deployment job
deploy-infrastructure:
  stage: deploy
  image: python:3.11
  tags:
    - docker
    - self-hosted
  before_script:
    - pip install ansible
  script:
    - echo "Deploying infrastructure changes"
    - ansible-playbook playbooks/site.yml --check --diff
  when: manual
  only:
    - main
```

---

## Complete Example: Application with Docker Build and Deploy

```yaml
# .gitlab-ci.yml for application repository
---
include:
  - local: '/ci-templates/docker-build.gitlab-ci.yml'
  - local: '/ci-templates/deployment-with-approval.gitlab-ci.yml'

variables:
  IMAGE_NAME: ${CI_REGISTRY_IMAGE}
  DOCKER_DRIVER: overlay2

stages:
  - build
  - test
  - staging
  - production
  - rollback

# Builds handled by docker-build.gitlab-ci.yml
# Deployments handled by deployment-with-approval.gitlab-ci.yml

# Add custom integration tests
integration-test:
  stage: test
  image: python:3.11
  tags:
    - docker
    - self-hosted
  script:
    - pip install pytest requests
    - pytest tests/integration/
  only:
    - branches
```

---

## Runner Configuration Requirements

All templates are designed to work with the GitLab Runner deployed via the `gitlab_runner_api` role:

**Runner Tags**:
- `docker` - Runner with Docker executor
- `linux` - Linux-based runner
- `self-hosted` - Self-hosted runner (not shared GitLab.com)

**Runner Configuration** (from `inventory/group_vars/all/gitlab_runner.yml`):
```yaml
gitlab_runner_executor: docker
gitlab_runner_tags:
  - docker
  - linux
  - self-hosted
gitlab_runner_docker_image: "debian:12"
gitlab_runner_docker_privileged: true
gitlab_runner_concurrent: 4
```

---

## Best Practices

1. **Version Control Templates**: Store templates in your GitLab repository for version control and easy updates

2. **Use Variables**: Customize behavior through GitLab CI/CD variables rather than editing templates

3. **Tag Jobs Appropriately**: Ensure jobs use correct runner tags (`docker`, `self-hosted`)

4. **Secure Secrets**: Store credentials in GitLab CI/CD variables (Settings → CI/CD → Variables) with:
   - Protected: Yes (for production variables)
   - Masked: Yes (to hide in logs)

5. **Test in Feature Branches**: Use `rules` or `only` to limit expensive jobs to specific branches

6. **Monitor Resource Usage**: Review runner resource usage and adjust `gitlab_runner_concurrent` if needed

7. **Cache Dependencies**: Use GitLab CI cache for package managers (npm, pip, cargo)

Example caching:
```yaml
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - .npm/
```

---

## Troubleshooting

### Job Stuck: "This job is stuck because you don't have any active runners"

**Solution**: Check runner status and tags
```bash
# On GitLab server
ssh root@gitlab.viljo.se
gitlab-runner list

# On runner container
ssh root@172.16.10.154
gitlab-runner verify
```

### Docker-in-Docker Fails: "Cannot connect to Docker daemon"

**Solution**: Ensure runner container has nesting enabled
```bash
# On Proxmox host
pct config 154 | grep features
# Should show: features: nesting=1
```

### Deployment SSH Key Issues

**Solution**: Verify SSH key is correctly formatted in GitLab variable
- Variable name: `DEPLOYMENT_SSH_KEY`
- Value should start with `-----BEGIN OPENSSH PRIVATE KEY-----`
- Ensure no extra whitespace or line breaks

---

## Template Maintenance

These templates are maintained in the `specs/planned/008-gitlab-cicd/ci-templates/` directory.

To update templates:
1. Edit template files in this directory
2. Test changes in a feature branch pipeline
3. Merge to main branch after validation
4. Existing pipelines will automatically use updated templates on next run

---

## Additional Resources

- [GitLab CI/CD YAML Syntax Reference](https://docs.gitlab.com/ee/ci/yaml/)
- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [Docker Executor Documentation](https://docs.gitlab.com/runner/executors/docker.html)

---

**Last Updated**: 2025-10-27
**Template Version**: 1.0.0
