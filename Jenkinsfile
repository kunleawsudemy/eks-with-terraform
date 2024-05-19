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
    stages{
        stage("AWS Demo"){
            steps{
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-jenkins-demo',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']])
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
}