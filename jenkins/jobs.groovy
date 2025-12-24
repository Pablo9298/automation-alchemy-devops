pipelineJob('automation-alchemy-devops') {
  triggers {
    scm('H/1 * * * *')   // polling раз в минуту
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
