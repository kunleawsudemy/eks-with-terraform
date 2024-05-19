pipeline {
    agent any
    tools {
        terraform 'terraform-11'
    }
    stages{
        stage('Git Checkout'){
            steps{
                git branch: 'master', credentialsId: 'GithubCredentials', url: 'https://github.com/kunleawsudemy/eks-with-terraform'
            }
        }
        stage('Terraform Init'){
            steps{
                sh 'terraform init'
            }
        }
        stage('Terraform Apply'){
            steps{
                sh 'terraform apply --auto-approve'
            }
        }
    }
}