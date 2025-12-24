pipeline {
  agent any

  triggers {
    pollSCM('H/1 * * * *')   // проверка изменений раз в минуту
  }

  environment {
    BACKEND_IMAGE = 'infrastructure-backend'
    APP_SERVER   = '192.168.56.13'
    WEB_SERVER_1 = '192.168.56.11'
    WEB_SERVER_2 = '192.168.56.12'
  }

  stages {

    stage('Checkout') {
      steps {
        echo 'Checking out source code...'
        checkout scm
      }
    }

    stage('Debug Jenkinsfile version') {
      steps {
        sh 'echo "Jenkinsfile loaded ✅ v2025-12-20-fullpaths"; sed -n "1,40p" Jenkinsfile || true'
      }
    }

    stage('Build Backend') {
      steps {
        echo 'Building backend Docker image...'
        dir('app/backend') {
          sh 'docker build -t ${BACKEND_IMAGE}:${BUILD_NUMBER} .'
          sh 'docker tag ${BACKEND_IMAGE}:${BUILD_NUMBER} ${BACKEND_IMAGE}:latest'
        }
      }
    }

    stage('Test Backend') {
      steps {
        echo 'Running backend smoke tests...'
        sh '''
          set -e

          docker rm -f backend-test >/dev/null 2>&1 || true
          docker run -d --name backend-test -p 3001:3000 ${BACKEND_IMAGE}:latest

          sleep 3
          curl -fsS http://localhost:3001/health
          curl -fsS http://localhost:3001/api/metrics > /dev/null

          docker rm -f backend-test
        '''
      }
    }

    stage('Deploy Backend') {
      steps {
        echo 'Deploying backend to app server...'
        sh """
          set -e
          IMAGE="${BACKEND_IMAGE}:latest"

          docker save "\$IMAGE" -o backend.tar

          scp -o StrictHostKeyChecking=no backend.tar devops@${APP_SERVER}:/tmp/backend.tar

          ssh -o StrictHostKeyChecking=no devops@${APP_SERVER} "
            set -e
            docker load -i /tmp/backend.tar
            docker rm -f backend >/dev/null 2>&1 || true
            docker run -d --name backend --restart always -p 3000:3000 \$IMAGE
            rm -f /tmp/backend.tar
          "

          rm -f backend.tar
        """
      }
    }

    stage('Deploy Frontend (static + nginx reload)') {
      steps {
        echo 'Deploying frontend static files to web servers...'
        sh '''
          set -e

          # web1
          scp -o StrictHostKeyChecking=no app/frontend/index.html devops@${WEB_SERVER_1}:/tmp/index.html
          scp -o StrictHostKeyChecking=no app/frontend/nginx.conf  devops@${WEB_SERVER_1}:/tmp/dashboard.conf
          ssh -o StrictHostKeyChecking=no devops@${WEB_SERVER_1} '
            set -e
            sudo /usr/bin/install -m 0644 /tmp/index.html /var/www/html/index.html
            sudo /usr/bin/install -m 0644 /tmp/dashboard.conf /etc/nginx/sites-available/dashboard
            sudo /bin/ln -sf /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/dashboard
            sudo /bin/rm -f /etc/nginx/sites-enabled/default || true
            sudo /usr/sbin/nginx -t
            sudo /usr/bin/systemctl reload nginx
          '

          # web2
          scp -o StrictHostKeyChecking=no app/frontend/index.html devops@${WEB_SERVER_2}:/tmp/index.html
          scp -o StrictHostKeyChecking=no app/frontend/nginx.conf  devops@${WEB_SERVER_2}:/tmp/dashboard.conf
          ssh -o StrictHostKeyChecking=no devops@${WEB_SERVER_2} '
            set -e
            sudo /usr/bin/install -m 0644 /tmp/index.html /var/www/html/index.html
            sudo /usr/bin/install -m 0644 /tmp/dashboard.conf /etc/nginx/sites-available/dashboard
            sudo /bin/ln -sf /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/dashboard
            sudo /bin/rm -f /etc/nginx/sites-enabled/default || true
            sudo /usr/sbin/nginx -t
            sudo /usr/bin/systemctl reload nginx
          '
        '''
      }
    }

    stage('Verify Deployment') {
      steps {
        echo 'Verifying backend from web servers (allowed path)...'
        sh """
          set -e

          echo '[web1] -> app /health'
          ssh -o StrictHostKeyChecking=no devops@${WEB_SERVER_1} 'curl -fsS http://${APP_SERVER}:3000/health'

          echo '[web2] -> app /health'
          ssh -o StrictHostKeyChecking=no devops@${WEB_SERVER_2} 'curl -fsS http://${APP_SERVER}:3000/health'
        """
      }
    }

  }

  post {
    always {
      echo 'Cleaning up...'
      sh 'docker image prune -f || true'
    }
    success {
      echo 'Pipeline completed successfully! ✅'
    }
    failure {
      echo 'Pipeline failed! ❌'
    }
  }
}
