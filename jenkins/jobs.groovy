pipelineJob('automation-alchemy-devops') {
  triggers {
    pollSCM('*/2 * * * *')
  }
  definition {
    cpsScm {
      scm {
        git {
          remote {
            url('https://github.com/Pablo9298/automation-alchemy-devops.git')
          }
          branches('*/main')
        }
      }
      scriptPath('Jenkinsfile')
    }
  }
}
