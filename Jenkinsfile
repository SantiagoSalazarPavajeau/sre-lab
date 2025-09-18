pipeline {
  agent any
  options {
    skipDefaultCheckout(true)
  }
  parameters {
    string(name: 'BRANCH', defaultValue: 'setup-jenkins', description: 'Git branch to check out')
    choice(name: 'APP_NAME', choices: ['app', 'facebook', 'netflix', 'slack'], description: 'Which mock app to build/deploy')
    booleanParam(name: 'SKIP_TERRAFORM', defaultValue: false, description: 'Skip Terraform provisioning stage')
    choice(name: 'TF_ACTION', choices: ['apply', 'plan'], description: 'Terraform action to run')
    string(name: 'TF_ENV', defaultValue: 'localstack', description: 'Terraform workspace/tfvars name under infra/terraform/environments')
    string(name: 'IMAGE_REGISTRY', defaultValue: '', description: 'Container registry prefix (e.g. docker.io/org). Leave blank for local-only builds')
    booleanParam(name: 'BOOTSTRAP_KIND', defaultValue: true, description: 'Create or update the local kind cluster before deploying')
    booleanParam(name: 'DEPLOY_INFRA', defaultValue: true, description: 'Apply baseline namespaces and infrastructure manifests')
    booleanParam(name: 'DEPLOY_MONITORING', defaultValue: true, description: 'Deploy monitoring stack after infra is ready')
    booleanParam(name: 'DEPLOY_CICD', defaultValue: true, description: 'Deploy cluster-side CI/CD components (e.g., Argo)')
    booleanParam(name: 'PUSH_MANIFEST', defaultValue: false, description: 'Commit and push manifest updates back to Git')
    booleanParam(name: 'SIMULATE_TLS_OUTAGE', defaultValue: false, description: 'Run TLS outage simulation stage')
    choice(name: 'TLS_ACTION', choices: ['prepare', 'outage', 'recover'], description: 'TLS simulation action')
  }
  stages {
    stage('Checkout') {
      steps {
        script {
          deleteDir()
          env.BRANCH = (params.BRANCH && params.BRANCH.trim()) ? params.BRANCH.trim() : 'main'
          checkout([
            $class: 'GitSCM',
            branches: [[name: "*/${env.BRANCH}" ]],
            userRemoteConfigs: scm.getUserRemoteConfigs(),
            extensions: []
          ])
        }
      }
    }
    stage('Prepare Vars') {
      steps {
        script {
          env.APP_NAME = params.APP_NAME ?: 'app'
          def registry = params.IMAGE_REGISTRY ? params.IMAGE_REGISTRY.trim() : ''
          env.IMAGE_REGISTRY = registry
          env.REGISTRY_LOGIN_HOST = ''
          if (registry) {
            def slashIdx = registry.indexOf('/')
            env.REGISTRY_LOGIN_HOST = (slashIdx > 0) ? registry.substring(0, slashIdx) : registry
          }
          env.IMAGE = registry ? "${registry}/sre-lab-${env.APP_NAME}" : "sre-lab-${env.APP_NAME}"
          env.PUSH_IMAGE = registry ? 'true' : 'false'
          env.K8S_MANIFEST = (env.APP_NAME == 'app') ? 'k8s/app/app-deployment.yaml' : "k8s/apps/${env.APP_NAME}/deployment.yaml"
          env.BRANCH = (params.BRANCH && params.BRANCH.trim()) ? params.BRANCH.trim() : 'main'
          env.TERRAFORM_ENV = (params.TF_ENV && params.TF_ENV.trim()) ? params.TF_ENV.trim() : 'localstack'
          env.TERRAFORM_ACTION = params.TF_ACTION ?: 'plan'
          env.BOOTSTRAP_KIND = params.BOOTSTRAP_KIND ? 'true' : 'false'
          env.DEPLOY_INFRA = params.DEPLOY_INFRA ? 'true' : 'false'
          env.DEPLOY_MONITORING = params.DEPLOY_MONITORING ? 'true' : 'false'
          env.DEPLOY_CICD = params.DEPLOY_CICD ? 'true' : 'false'
          env.PUSH_MANIFEST = params.PUSH_MANIFEST ? 'true' : 'false'
          env.GIT_COMMIT_SHORT = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : 'localdev'
        }
        sh 'echo Using APP_NAME=${APP_NAME} IMAGE=${IMAGE} K8S_MANIFEST=${K8S_MANIFEST}'
      }
    }
    stage('Bootstrap kind Cluster') {
      when { expression { return env.BOOTSTRAP_KIND == 'true' } }
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
start-up/cluster-up.sh
if [ "${DEPLOY_INFRA}" = "true" ]; then
  start-up/deploy-infra.sh
fi
if [ "${DEPLOY_MONITORING}" = "true" ]; then
  start-up/deploy-monitoring.sh
fi
if [ "${DEPLOY_CICD}" = "true" ]; then
  start-up/deploy-cicd.sh
fi
        '''
      }
    }
    stage('Provision Infrastructure') {
      when { expression { return !params.SKIP_TERRAFORM } }
      steps {
        script {
          env.LOCALSTACK_ENDPOINT = 'http://localhost:4566'
        }
        dir('infra/localstack') {
          sh 'docker compose up -d'
          script {
            def status = sh(returnStatus: true, script: '''#!/usr/bin/env bash
set -euo pipefail
container_id=$(docker compose ps -q localstack)
endpoint=${LOCALSTACK_ENDPOINT:-http://localhost:4566}
if [ -n "$container_id" ]; then
  networks=$(docker container inspect "$container_id" --format '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}} {{end}}')
  for net in $networks; do
    docker network connect "$net" $(hostname) >/dev/null 2>&1 || true
  done
  container_ip=$(docker container inspect "$container_id" --format '{{range $name, $conf := .NetworkSettings.Networks}}{{$conf.IPAddress}}{{" "}}{{end}}' | awk '{print $1}')
  if [ -n "$container_ip" ]; then
    echo "LOCALSTACK_ENDPOINT_INTERNAL=http://$container_ip:4566" >> "$WORKSPACE/.localstack_tmp"
    endpoint="http://$container_ip:4566"
  fi
fi
LOCALSTACK_MAX_ATTEMPTS=${LOCALSTACK_MAX_ATTEMPTS:-60} \
LOCALSTACK_SLEEP_SECONDS=${LOCALSTACK_SLEEP_SECONDS:-5} \
./wait-for-localstack.sh "$endpoint"
''')
            if (status != 0) {
              sh 'docker compose logs localstack || true'
              error 'LocalStack failed to become ready'
            }
            if (fileExists("${WORKSPACE}/.localstack_tmp")) {
              def content = readFile("${WORKSPACE}/.localstack_tmp").trim()
              content.split('\n').each { line ->
                def parts = line.split('=')
                if (parts.size() == 2 && parts[0] == 'LOCALSTACK_ENDPOINT_INTERNAL') {
                  env.LOCALSTACK_ENDPOINT = parts[1]
                }
              }
              sh "rm -f ${WORKSPACE}/.localstack_tmp"
            }
            env.LOCALSTACK_ENDPOINT = env.LOCALSTACK_ENDPOINT ?: 'http://localhost:4566'
            echo "[jenkins] LOCALSTACK_ENDPOINT resolved to ${env.LOCALSTACK_ENDPOINT}"
          }
        }
        dir('infra/terraform') {
          sh '''#!/usr/bin/env bash
set -euo pipefail
terraform init -input=false
terraform workspace select ${TERRAFORM_ENV} || terraform workspace new ${TERRAFORM_ENV}
if [ "${TERRAFORM_ACTION}" = "plan" ]; then
  terraform plan -input=false -var-file="environments/${TERRAFORM_ENV}.tfvars" -var="localstack_endpoint=${LOCALSTACK_ENDPOINT}" -out=tfplan
else
  terraform apply -input=false -auto-approve -var-file="environments/${TERRAFORM_ENV}.tfvars" -var="localstack_endpoint=${LOCALSTACK_ENDPOINT}"
  terraform output
fi
          '''
        }
      }
      post {
        always {
          dir('infra/localstack') {
            sh 'docker compose down || true'
            sh '''#!/usr/bin/env bash
set -euo pipefail
network_name="localstack_default"
docker network disconnect "$network_name" $(hostname) >/dev/null 2>&1 || true
'''
          }
        }
      }
    }
    stage('Build') {
      steps {
        sh 'docker build -t ${IMAGE}:${GIT_COMMIT_SHORT} ./src/services/${APP_NAME}'
      }
    }
    stage('Push') {
      when { expression { return env.PUSH_IMAGE == 'true' } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'registry-creds', usernameVariable: 'REG_USR', passwordVariable: 'REG_PSW')]) {
          sh '''#!/usr/bin/env bash
set -euo pipefail
if [ -n "${REGISTRY_LOGIN_HOST}" ]; then
  echo "$REG_PSW" | docker login "${REGISTRY_LOGIN_HOST}" -u "$REG_USR" --password-stdin
else
  echo "$REG_PSW" | docker login -u "$REG_USR" --password-stdin
fi
docker push "${IMAGE}:${GIT_COMMIT_SHORT}"
'''
        }
      }
    }
    stage('Update Manifests') {
      when { expression { return env.PUSH_MANIFEST == 'true' } }
      steps {
        sh """
          yq e -i '.spec.template.spec.containers[0].image = \"${IMAGE}:${GIT_COMMIT_SHORT}\"' ${K8S_MANIFEST}
          git config user.email "ci@example.com"
          git config user.name "ci-bot"
          git add ${K8S_MANIFEST}
          git commit -m "ci: deploy image ${GIT_COMMIT_SHORT}" || echo "[info] nothing to commit"
          git push origin HEAD:main
        """
      }
    }
    stage('TLS Outage Simulation') {
      when { expression { return params.SIMULATE_TLS_OUTAGE } }
      steps {
        script {
          if (params.TLS_ACTION == 'prepare') {
            sh 'scripts/tls_prepare.sh'
          } else if (params.TLS_ACTION == 'outage') {
            sh 'scripts/tls_outage_start.sh'
          } else if (params.TLS_ACTION == 'recover') {
            sh 'scripts/tls_outage_recover.sh'
          } else {
            error("Unknown TLS_ACTION: ${params.TLS_ACTION}")
          }
        }
      }
    }
  }
}
