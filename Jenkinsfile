def stagestatus = [:] 

pipeline {
  environment {
    image_mw = "i_golubovich/wp"
    registry = "jfrog.it-academy.by/public/"
    registryCredential = 'jf'
    ckube = "/var/ckube/config"
  }
  agent {label 'master'}
  stages {
     stage('Slack start pipeline'){
        steps {
            slackSend channel: '#igoz_notification_channel', 
                      message: "START Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})",
                      color: '#F0FFFF'
            }
        }
    stage('Cloning Git') {
      steps {
        git url: 'https://github.com/igor-golubovich/final_project.git', branch: 'master', credentialsId: "git_project_token"
      }
    }
    
    stage('Building image') {
      steps {
        script {
          try {
            dockerImage = docker.build registry + image_mw + ":$BUILD_NUMBER" , "."
            stagestatus.Docker_BUILD = "Success"
          } catch (Exception err) {
            stagestatus.Docker_BUILD = "Failure"
            error "Dockerfile is broken, please check your Dockerfile"
          //dockerImage = docker.build registry + ":$BUILD_NUMBER" , "--network host ."
          }
        }
      }
    }

    stage("Push image") {
      steps {
        script {
          catchError (buildResult: 'SUCCESS', stageResult: 'FAILURE') {
            try {
              docker.withRegistry( 'https://jfrog.it-academy.by', registryCredential ) {
              dockerImage.push("${env.BUILD_ID}")
              }
              stagestatus.Docker_PUSH = "Success"
            } catch (Exception err) {
              stagestatus.Docker_PUSH = "Failure"
              error "Image pushing error"              
              }
          }
        }
      }
    }

    stage('Slack pushing error'){
      when { 
          expression { stagestatus.find{ it.key == "Docker_PUSH" }?.value == "Failure" }
      }
            steps {
                slackSend channel: '#igoz_notification_channel', 
                          message: 'Image pushing ERROR',
                          color: '#FF0000'
            }
        }
    
    stage('Remove unused docker images') {
      steps{
        sh "docker rmi $registry$image_mw:$BUILD_NUMBER"
      }
    }
    
    stage('Kubeval tests') {    
        steps {
          script {
            catchError (buildResult: 'SUCCESS', stageResult: 'FAILURE') {
              try {
                sh 'kubeval --strict --schema-location https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/ deploy/wordpress.yaml > kubeval.log'
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



stage("Deploy or Upgrade") {
      when { 
        allOf {
          expression { stagestatus.find{ it.key == "Docker_PUSH" }?.value == "Success" }
          expression { stagestatus.find{ it.key == "Kubeval" }?.value == "Success" }
        }
      }   
      steps {
        script {
          catchError (buildResult: 'SUCCESS', stageResult: 'FAILURE') {
            try {
              if (sh(returnStdout: true, script: 'kubectl get deployment wordpress --ignore-not-found --namespace default --kubeconfig=$ckube') == '') {
                sh """
                    sed -i "s|image_variable|$registry$image_mw:${env.BUILD_ID}|g" deploy/wordpress.yaml
                    kubectl apply -f deploy/wordpress.yaml --namespace=default --kubeconfig=$ckube
                  """
              }
              else {
                sh "kubectl scale --replicas=0 deploy/wordpress --namespace default --kubeconfig=$ckube"
                sh "kubectl delete -l name=wp-pv-claim -f deploy/wordpress.yaml --namespace default --kubeconfig=$ckube"
                sh "kubectl apply -l name=wp-pv-claim -f deploy/wordpress.yaml --namespace default --kubeconfig=$ckube"
                sh "kubectl set image deploy/wordpress wordpress=$registry$image_mw:${env.BUILD_ID} --namespace default --kubeconfig=$ckube"
                sh "kubectl scale --replicas=1 deploy/wordpress --namespace default --kubeconfig=$ckube"
                stagestatus.Upgrade = "Success"
              }
              stagestatus.Deploy = "Success"
            } catch (Exception err) {
                stagestatus.Deploy = "Failure"
                stagestatus.Upgrade = "Failure"
                error "Deployment or Upgrade are failed"
              }
          }
        }
      }
    }
stage('Slack deploy error'){
      when { 
        anyOf {
          expression { stagestatus.find{ it.key == "Deploy" }?.value == "Failure" }
          expression { stagestatus.find{ it.key == "Upgrade" }?.value == "Failure" }
        } 
      }
            steps {
                slackSend channel: '#igoz_notification_channel', 
                          message: 'Deploy or Upgrade ERROR',
                          color: '#FF0000'
            }
        }

stage("Rollback") {
      when { 
          expression { stagestatus.find{ it.key == "Upgrade" }?.value == "Failure" }
      }
      steps {
        script {
          sh "kubectl scale --replicas=0 deploy/wordpress --namespace default --kubeconfig=$ckube"
          sh "kubectl delete -l name=wp-pv-claim -f deploy/wordpress.yaml --namespace default --kubeconfig=$ckube"
          sh "kubectl apply -l name=wp-pv-claim -f deploy/wordpress.yaml --namespace default --kubeconfig=$ckube"
          sh "kubectl rollout undo deploy/wordpress --namespace default --kubeconfig=$ckube"
          sh "kubectl scale --replicas=1 deploy/wordpress --namespace default --kubeconfig=$ckube"
        }
      }
    }
  } 

 post {
    success {
        slackSend (color: '#00FF00', message: "SUCCESSFUL: Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
    }
    failure {
        slackSend (color: '#FF0000', message: "FAILED: Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
    }
  }

}
