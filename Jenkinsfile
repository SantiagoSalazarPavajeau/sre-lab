pipeline {
  agent any
  parameters {
    booleanParam(name: 'SIMULATE_TLS_OUTAGE', defaultValue: false, description: 'Run TLS outage simulation stage')
    choice(name: 'TLS_ACTION', choices: ['prepare', 'outage', 'recover'], description: 'TLS simulation action')
    choice(name: 'APP_NAME', choices: ['app', 'facebook', 'netflix', 'slack'], description: 'Which mock app to build/deploy')
  }
  environment { }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Prepare Vars') {
      steps {
        script {
          env.APP_NAME = params.APP_NAME ?: 'app'
          env.IMAGE = "docker.io/<your-registry>/sre-lab-${env.APP_NAME}"
          env.K8S_MANIFEST = (env.APP_NAME == 'app') ? 'k8s/app/app-deployment.yaml' : "k8s/apps/${env.APP_NAME}/deployment.yaml"
        }
        sh 'echo Using APP_NAME=${APP_NAME} IMAGE=${IMAGE} K8S_MANIFEST=${K8S_MANIFEST}'
      }
    }
    stage('Build') {
      steps {
        sh 'docker build -t ${IMAGE}:${GIT_COMMIT::8} ./src/services/${APP_NAME}'
      }
    }
    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'registry-creds', usernameVariable: 'REG_USR', passwordVariable: 'REG_PSW')]) {
          sh 'echo $REG_PSW | docker login docker.io -u $REG_USR --password-stdin'
          sh 'docker push ${IMAGE}:${GIT_COMMIT::8}'
        }
      }
    }
    stage('Update Manifests') {
      steps {
        sh """
          yq e -i '.spec.template.spec.containers[0].image = \"${IMAGE}:${GIT_COMMIT::8}\"' ${K8S_MANIFEST}
          git config user.email "ci@example.com"
          git config user.name "ci-bot"
          git add ${K8S_MANIFEST}
          git commit -m "ci: deploy image ${GIT_COMMIT::8}"
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
