pipeline {
  agent any
  environment {
    IMAGE = 'docker.io/<your-registry>/sre-lab-app'
    K8S_MANIFEST = 'k8s/app-deployment.yaml'
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build') {
      steps {
        sh 'docker build -t ${IMAGE}:${GIT_COMMIT::8} ./src/services/app'
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
  }
}
