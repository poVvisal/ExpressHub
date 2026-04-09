pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: "https://github.com/poVvisal/ExpressHub.git"
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform/dev') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }

    post {
        failure {
            dir('terraform/dev') {
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}
