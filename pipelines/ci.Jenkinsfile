pipeline {
    agent any

    environment {
        //Input parameters
        param_git_branch = "${params.GitBranch}"
        param_profile = "${params.Profile}"
        param_legion_infra_repo = "${params.LegionInfraRepo}"
        param_legion_infra_version = "${params.LegionInfraVersion}"
        param_legion_version = "${params.LegionVersion}"
        param_build_legion_airflow_job_name = "${params.BuildLegionAirflowJobName}"
        param_terminate_cluster_job_name = "${params.TerminateClusterJobName}"
        param_create_cluster_job_name = "${params.CreateClusterJobName}"
        param_deploy_legion_job_name = "${params.DeployLegionJobName}"
        param_deploy_legion_airflow_job_name = "${params.DeployLegionAirflowJobName}"
        param_undeploy_legioin_airflow_job_name = "${params.UndeployLegionAirflowJobName}"
        param_legion_release_commit_id = "${params.LegionReleaseCommitId}"
        //Job parameters
        sharedLibPath = "pipelines/Pipeline.groovy"
        legionSharedLibPath = "pipelines/legionPipeline.groovy"
        legionAirflowVersion = null
        ansibleHome =  "/opt/legion/ansible"
        ansibleVerbose = '-v'
        mergeBranch = "ci/${params.GitBranch}"
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                script {

                    print('Set interim merge branch')
                    sh """
                    echo ${env.mergeBranch}
                    if [ `git branch | grep ${env.mergeBranch}` ]; then
                        echo 'Removing existing git tag'
                        git branch -D ${env.mergeBranch}
                        git push origin --delete ${env.mergeBranch}
                    fi
                    git branch ${env.mergeBranch}
                    git push origin ${env.mergeBranch}
                    """ 
                
                    // Import legion-airflow components
                    legionAirflow = load "${env.sharedLibPath}"
                
                    // Import Legion components
                    dir("${WORKSPACE}/legion") {
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false 
                        legion = load "${env.legionSharedLibPath}"
                    }

                    legion.buildDescription()
                }
            }
        }

       stage('Build Legion Airflow') {
           steps {
               script {
                   print "starting airflow build"
                   result = build job: env.param_build_legion_airflow_job_name, propagate: true, wait: true, parameters: [
                        [$class: 'GitParameterValue', name: 'GitBranch', value: env.mergeBranch],
                        booleanParam(name: 'EnableDockerCache', value: false),
                        string(name: 'LegionInfraVersion', value: env.param_legion_infra_version)]

                   buildNumber = result.getNumber()
                   print 'Finished build id ' + buildNumber.toString()

                   // Copy artifacts
                   copyArtifacts filter: '*', flatten: true, fingerprintArtifacts: true, projectName: env.param_build_legion_airflow_job_name, selector: specific      (buildNumber.toString()), target: ''

                   // \ Load variables
                   def map = [:]
                   def envs = sh returnStdout: true, script: "cat file.env"

                   envs.split("\n").each {
                       kv = it.split('=', 2)
                       print "Loaded ${kv[0]} = ${kv[1]}"
                       map[kv[0]] = kv[1]
                   }

                   legionAirflowVersion = map["LEGION_VERSION"]

                   print "Loaded version ${legionAirflowVersion}"
                   // Load variables

                   if (!legionAirflowVersion) {
                       error 'Cannot get legion airflow release version number'
                   }
               }
           }
       }

       stage('Terminate Cluster if exists') {
           steps {
               script {
                   result = build job: env.param_terminate_cluster_job_name, propagate: true, wait: true, parameters: [
                           [$class: 'GitParameterValue', name: 'GitBranch', value: env.param_legion_infra_version],
                           string(name: 'LegionInfraVersion', value: env.param_legion_infra_version),
                           string(name: 'Profile', value: env.param_profile),
                   ]
               }
           }
       }

       stage('Create Cluster') {
           steps {
               script {
                   result = build job: env.param_create_cluster_job_name, propagate: true, wait: true, parameters: [
                           [$class: 'GitParameterValue', name: 'GitBranch', value: env.param_legion_infra_version],
                           string(name: 'Profile', value: env.param_profile),
                           string(name: 'LegionInfraVersion', value: env.param_legion_infra_version),
                           booleanParam(name: 'SkipKops', value: false)
                   ]
               }
           }
       }

       stage('Deploy Legion') {
           steps {
               script {
                   result = build job: env.param_deploy_legion_job_name, propagate: true, wait: true, parameters: [
                           [$class: 'GitParameterValue', name: 'GitBranch', value: env.param_legion_infra_version],
                           string(name: 'Profile', value: env.param_profile),
                           string(name: 'LegionInfraVersion', value: env.param_legion_infra_version),
                           string(name: 'LegionVersion', value: env.param_legion_version),
                           string(name: 'TestsTags', value: ""),
                           string(name: 'commitID', value: "env.param_legion_release_commit_id"),
                           booleanParam(name: 'DeployLegion', value: true),
                           booleanParam(name: 'CreateJenkinsTests', value: false),
                           booleanParam(name: 'UseRegressionTests', value: false)
                   ]
               }
           }
       }

       stage('Deploy Legion Airflow') {
           steps {
               script {
                   result = build job: env.param_deploy_legion_airflow_job_name, propagate: true, wait: true, parameters: [
                           [$class: 'GitParameterValue', name: 'GitBranch', value: env.mergeBranch],
                           string(name: 'Profile', value: env.param_profile),
                           string(name: 'LegionAirflowVersion', value: legionAirflowVersion),
                           string(name: 'LegionInfraVersion', value: env.param_legion_infra_version),
                           booleanParam(name: 'DeployAirflow', value: true),
                           booleanParam(name: 'UseRegressionTests', value: false),
                           string(name: 'EnclaveName', value: 'company-a')
                   ]
               }
           }
       }

       stage('Undeploy Legion Airflow') {
           steps {
               script {
                   result = build job: env.param_undeploy_legioin_airflow_job_name, propagate: true, wait: true, parameters: [
                           [$class: 'GitParameterValue', name: 'GitBranch', value: env.mergeBranch],
                           string(name: 'Profile', value: env.param_profile),
                           string(name: 'LegionAirflowVersion', value: legionAirflowVersion),
                           string(name: 'LegionInfraVersion', value: env.param_legion_infra_version),
                           string(name: 'EnclaveName', value: 'company-a')
                   ]
               }
           }
       }
   }

    post {
        always {
            script {
                // import Legion components
                dir("${WORKSPACE}/legion") {
                    checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false 
                    legion = load "${env.legionSharedLibPath}"
                }

                result = build job: env.param_terminate_cluster_job_name, propagate: true, wait: true, parameters: [
                        [$class: 'GitParameterValue', name: 'GitBranch', value: env.param_legion_infra_version],
                        string(name: 'LegionInfraVersion', value: env.param_legion_infra_version),
                        string(name: 'Profile', value: env.param_profile)]

                legion.notifyBuild(currentBuild.currentResult)
            }
        }
        cleanup {
            script {
                print('Remove interim merge branch')
                sh """
                    if [ `git branch | grep ${env.mergeBranch}` ]; then
                        git branch -D ${env.mergeBranch}
                        git push origin --delete ${env.mergeBranch}
                    fi
                """
            }
            deleteDir()
        }
    }
}
