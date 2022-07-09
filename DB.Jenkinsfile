def stagestatus = [:] 

pipeline {
  environment {
    image_bd = "mysql:8.0"
    ckube = "/var/ckube/config"
  }
  agent {label 'master'}
  stages {
     stage('Slack start pipeline'){
        steps {
            slackSend channel: '#igoz_notification_channel', 
                      message: "START DB Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})",
                      color: '#F0FFFF'
            }
        }
    stage('Cloning Git') {
      steps {
        git url: 'https://github.com/igor-golubovich/final_project.git', branch: 'master', credentialsId: "git_project_token"
      }
    }
    
    stage('Kubeval tests') {    
        steps {
          script {
            catchError (buildResult: 'SUCCESS', stageResult: 'FAILURE') {
              try {
                sh """
                echo "\$(date) " ${env.JOB_NAME} [${env.BUILD_NUMBER}] >> kubeval.log
                kubeval --strict --schema-location https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/ deploy/mysql.yaml >> kubeval.log
                echo "\n" >> kubeval.log
                """
                archiveArtifacts artifacts: 'kubeval.log'
                stagestatus.Kubeval = "Success"
              } catch (Exception err) {
                stagestatus.Kubeval = "Failure"
                error "manifest syntax is incorrect"
              }
            }
          }
        }
    } 



stage("Deploy or Upgrade DB") {
      when { 
          expression { stagestatus.find{ it.key == "Kubeval" }?.value == "Success" }     
      }   
      steps {
        script {
          catchError (buildResult: 'SUCCESS', stageResult: 'FAILURE') {   
            try {
              if (sh(returnStdout: true, script: 'kubectl get deployment wordpress-mysql --ignore-not-found --namespace default --kubeconfig=$ckube') == '') {
                sh """
                    sed -i "s|image_variable|$image_bd|g" deploy/mysql.yaml
                    kubectl apply -f deploy/mysql.yaml --namespace=default --kubeconfig=$ckube
                  """
              }
              else {
                sh "kubectl scale --replicas=0 deployment/wordpress-mysql --namespace default --kubeconfig=$ckube"
                sh "kubectl delete -l name=mysql-pv-claim -f deploy/mysql.yaml --namespace default --kubeconfig=$ckube"
                sh "kubectl apply -l name=mysql-pv-claim -f deploy/mysql.yaml --namespace default --kubeconfig=$ckube"
                sh "kubectl set image deployment/wordpress-mysql wordpress-mysql=$image_bd --namespace default --kubeconfig=$ckube"
                sh "kubectl scale --replicas=1 deployment/wordpress-mysql --namespace default --kubeconfig=$ckube"
                stagestatus.Upgrade = "Success"
              }
              stagestatus.Deploy_BD = "Success"
            } catch (Exception err) {
                stagestatus.Deploy_BD = "Failure"
                stagestatus.Upgrade_BD = "Failure"
                error "Deployment or Upgrade BD failed"
              }
          }
        }
      }
    }



stage('Slack DB deploy error'){
      when { 
        anyOf {
          expression { stagestatus.find{ it.key == "Deploy_BD" }?.value == "Failure" }
          expression { stagestatus.find{ it.key == "Upgrade_BD" }?.value == "Failure" }
        } 
      }
            steps {
                slackSend channel: '#igoz_notification_channel', 
                          message: 'Deploy or Upgrade DB ERROR',
                          color: '#FF0000'
            }
        }

stage("Rollback") {
      when { 
          expression { stagestatus.find{ it.key == "Upgrade" }?.value == "Failure" }
      }
      steps {
        script {
          sh "kubectl scale --replicas=0 deployment//wordpress-mysql --namespace default --kubeconfig=$ckube"
          sh "kubectl delete -l name=wp-pv-claim -f deploy/mysql.yaml --namespace default --kubeconfig=$ckube"
          sh "kubectl apply -l name=wp-pv-claim -f deploy/mysql.yaml --namespace default --kubeconfig=$ckube"
          sh "kubectl rollout undo deployment/wordpress-mysql --namespace default --kubeconfig=$ckube"
          sh "kubectl scale --replicas=1 deployment/wordpress-mysql --namespace default --kubeconfig=$ckube"
        }
      }
    }
  } 

 post {
    success {
        slackSend (color: '#00FF00', message: "SUCCESSFUL: BD Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
    }
    failure {
        slackSend (color: '#FF0000', message: "FAILED: BD Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
    }
  }

}
