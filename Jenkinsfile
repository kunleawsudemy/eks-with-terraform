// pipeline {
//     agent any
//     tools {
//         terraform 'terraform-11'
//     }
//     stages{
//         stage('Git Checkout'){
//             steps{
//                 git branch: 'master', credentialsId: 'GithubCredentials', url: 'https://github.com/kunleawsudemy/eks-with-terraform'
//             }
//         }
//         stage('Terraform Init'){
//             steps{
//                 sh 'terraform init -migrate-state'
//             }
//         }
//         stage('Terraform Apply'){
//             steps{
//                 sh 'terraform apply --auto-approve'
//             }
//         }
//     }
// }
pipeline {
    agent any
    environment {
        AWS_CREDENTIALS = credentials('aws-secret-credentials')
    }
    stages {
        stage('AWS Demo') {
            steps {
                script {
                    // Read the contents of the secret file
                    def credsFileContent = readFile "${AWS_CREDENTIALS}"
                    
                    // Parse the content to get access key ID and secret access key
                    def awsAccessKeyId = credsFileContent.readLines().find { it.startsWith('AWS_ACCESS_KEY_ID=') }?.split('=')[1]?.trim()
                    def awsSecretAccessKey = credsFileContent.readLines().find { it.startsWith('AWS_SECRET_ACCESS_KEY=') }?.split('=')[1]?.trim()
                    
                    // Use the credentials in your AWS-related steps
                    sh "export AWS_ACCESS_KEY_ID=${awsAccessKeyId} && export AWS_SECRET_ACCESS_KEY=${awsSecretAccessKey}"
                }
            }
        }
    }
        stage('Terraform Init') {
            steps {
                // Assuming terraform executable is in the PATH
                sh 'terraform init -migrate-state'
            }
        }
        stage('Terraform Apply') {
            steps {
                // Assuming terraform executable is in the PATH
                sh 'terraform apply -auto-approve'
            }
        }
    }
