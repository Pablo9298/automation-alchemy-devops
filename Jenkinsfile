pipeline {
    agent any
    
    environment {
        BACKEND_IMAGE = 'infrastructure-backend'
        FRONTEND_IMAGE = 'infrastructure-frontend'
        APP_SERVER = '192.168.56.13'
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
        
        stage('Build Backend') {
            steps {
                echo 'Building backend Docker image...'
                dir('app/backend') {
                    sh 'docker build -t ${BACKEND_IMAGE}:${BUILD_NUMBER} .'
                    sh 'docker tag ${BACKEND_IMAGE}:${BUILD_NUMBER} ${BACKEND_IMAGE}:latest'
                }
            }
        }
        
        stage('Build Frontend') {
            steps {
                echo 'Building frontend Docker image...'
                dir('app/frontend') {
                    sh 'docker build -t ${FRONTEND_IMAGE}:${BUILD_NUMBER} .'
                    sh 'docker tag ${FRONTEND_IMAGE}:${BUILD_NUMBER} ${FRONTEND_IMAGE}:latest'
                }
            }
        }
        
        stage('Test Backend') {
            steps {
                echo 'Running backend tests...'
                sh '''
                    # Run a test container
                    docker run -d --name backend-test -p 3001:3000 ${BACKEND_IMAGE}:latest
                    
                    # Wait for container to start
                    sleep 5
                    
                    # Test health endpoint
                    curl -f http://localhost:3001/health || exit 1
                    
                    # Test metrics endpoint
                    curl -f http://localhost:3001/api/metrics || exit 1
                    
                    # Cleanup
                    docker stop backend-test
                    docker rm backend-test
                '''
            }
        }
        
        stage('Deploy Backend') {
            steps {
                echo 'Deploying backend to app server...'
                sh '''
                    # Save image as tar
                    docker save ${BACKEND_IMAGE}:latest -o backend.tar
                    
                    # Copy to app server
                    scp -o StrictHostKeyChecking=no backend.tar devops@${APP_SERVER}:/tmp/
                    
                    # Load and run on app server
                    ssh -o StrictHostKeyChecking=no devops@${APP_SERVER} '
                        docker load -i /tmp/backend.tar
                        docker stop backend || true
                        docker rm backend || true
                        docker run -d --name backend --restart always -p 3000:3000 ${BACKEND_IMAGE}:latest
                        rm /tmp/backend.tar
                    '
                    
                    rm backend.tar
                '''
            }
        }
        
        stage('Deploy Frontend') {
            steps {
                echo 'Deploying frontend to web servers...'
                sh '''
                    # Save image as tar
                    docker save ${FRONTEND_IMAGE}:latest -o frontend.tar
                    
                    # Deploy to web server 1
                    scp -o StrictHostKeyChecking=no frontend.tar devops@${WEB_SERVER_1}:/tmp/
                    ssh -o StrictHostKeyChecking=no devops@${WEB_SERVER_1} '
                        docker load -i /tmp/frontend.tar
                        docker stop frontend || true
                        docker rm frontend || true
                        docker run -d --name frontend --restart always -p 80:80 ${FRONTEND_IMAGE}:latest
                        rm /tmp/frontend.tar
                    '
                    
                    # Deploy to web server 2
                    scp -o StrictHostKeyChecking=no frontend.tar devops@${WEB_SERVER_2}:/tmp/
                    ssh -o StrictHostKeyChecking=no devops@${WEB_SERVER_2} '
                        docker load -i /tmp/frontend.tar
                        docker stop frontend || true
                        docker rm frontend || true
                        docker run -d --name frontend --restart always -p 80:80 ${FRONTEND_IMAGE}:latest
                        rm /tmp/frontend.tar
                    '
                    
                    rm frontend.tar
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    # Check backend
                    curl -f http://${APP_SERVER}:3000/health || exit 1
                    
                    # Check web servers
                    curl -f http://${WEB_SERVER_1} || exit 1
                    curl -f http://${WEB_SERVER_2} || exit 1
                    
                    echo "All services are healthy!"
                '''
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully! ✅'
            // Here you can add Slack/Email notifications
        }
        failure {
            echo 'Pipeline failed! ❌'
            // Here you can add Slack/Email notifications
        }
        always {
            echo 'Cleaning up...'
            sh 'docker image prune -f'
        }
    }
}
