pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = "your-access-key-id"
        AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
        AWS_DEFAULT_REGION    = "us-east-1"
    }

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
}