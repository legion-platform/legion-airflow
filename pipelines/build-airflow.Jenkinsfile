import java.text.SimpleDateFormat

class Globals {
    static String rootCommit = null
    static String buildVersion = null
    static String dockerLabels = null
    static String dockerCacheArg = null
}

pipeline {
    agent { label 'ec2builder'}

    options{
            buildDiscarder(logRotator(numToKeepStr: '35', artifactNumToKeepStr: '35'))
            disableConcurrentBuilds()
        }
    environment {
            /// Input parameters
            //Enable docker cache parameter
            param_enable_docker_cache = "${params.EnableDockerCache}"
            //Build major version release and optionally push it to public repositories
            param_stable_release = "${params.StableRelease}"
            //Release version to tag all artifacts to
            param_release_version = "${params.ReleaseVersion}"
            //Git Branch to build package from
            param_git_branch = "${params.GitBranch}"
             //Legion Infra repo url (for pipeline methods import)
            param_legion_infra_repo = "${params.LegionInfraRepo}"
            //Legion repo version tag (tag or branch name)
            param_legion_infra_version = "${params.LegionInfraVersion}"
            //Legion repo url (for pipeline methods import)
            param_legion_repo = "${params.LegionRepo}"
            //Legion repo version tag (tag or branch name)
            param_legion_version_tag = "${params.LegionVersionTag}"
            //Push release git tag
            param_push_git_tag = "${params.PushGitTag}"
            //Rewrite git tag i exists
            param_force_tag_push = "${params.ForceTagPush}"
            //Push release to master bransh
            param_update_master = "${params.UpdateMaster}"
            //Set next releases version explicitly
            param_next_version = "${params.NextVersion}"
            // Update version string
            param_update_version_string = "${params.UpdateVersionString}"
            // Release version to be used as docker cache source
            param_docker_cache_source = "${params.DockerCacheSource}"
            //Artifacts storage parameters
            param_helm_repo_git_url = "${params.HelmRepoGitUrl}"
            param_helm_repo_git_branch = "${params.HelmRepoGitBranch}"
            param_helm_repository = "${params.HelmRepository}"
            param_pypi_repository = "${params.PyPiRepository}"
            param_local_pypi_distribution_target_name = "${params.LocalPyPiDistributionTargetName}"
            param_docker_registry = "${params.DockerRegistry}"
            param_docker_hub_registry = "${params.DockerHubRegistry}"
            param_git_deploy_key = "${params.GitDeployKey}"
            ///Job parameters
            sharedLibPath = "pipelines/Pipeline.groovy"
            legionSharedLibPath = "pipelines/legionPipeline.groovy"
            updateVersionScript = "tools/update_version_id"
            pathToCharts= "${WORKSPACE}/helms"
    }

    stages {

        stage('Checkout and set build vars') {
            steps {
                cleanWs()
                checkout scm
                script {
                    sh 'echo RunningOn: $(curl http://checkip.amazonaws.com/)'

                    legionAirflow = load "${env.sharedLibPath}"

                    // import Legion components
                    dir("${WORKSPACE}/legion") {
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false
                        legion = load "${env.legionSharedLibPath}"
                    }
                    
                    print("Check code for security issues")
                    sh "bash install-git-secrets-hook.sh install_hooks && git secrets --scan -r"

                    legion.setBuildMeta(env.updateVersionScript)
                }
            }
        }

        // Set Git Tag in case of stable release
        stage('Set GIT release Tag'){
            steps {
                script {
                    if (env.param_stable_release.toBoolean() && env.param_push_git_tag.toBoolean()){
                        legion.setGitReleaseTag()
                    }
                    else {
                        print("Skipping release git tag push")
                    }
                }
            }
        }

        stage("Docker login") {
            steps {
                withCredentials([[
                 $class: 'UsernamePasswordMultiBinding',
                 credentialsId: 'nexus-local-repository',
                 usernameVariable: 'USERNAME',
                 passwordVariable: 'PASSWORD']]) {
                    sh "docker login -u ${USERNAME} -p ${PASSWORD} ${env.param_docker_registry}"
                }
                script {
                    if (env.param_stable_release) {
                        withCredentials([[
                        $class: 'UsernamePasswordMultiBinding',
                        credentialsId: 'dockerhub',
                        usernameVariable: 'USERNAME',
                        passwordVariable: 'PASSWORD']]) {
                            sh "docker login -u ${USERNAME} -p ${PASSWORD}"
                        }
                    }
                }
            }
        }

        stage('Build Agent Docker Image') {
            steps {
                script {
                    legion.buildLegionImage('airflow-pipeline-agent', '.', 'containers/agent/Dockerfile')
                    legion.uploadDockerImage('airflow-pipeline-agent')
                }
            }
        }

        stage('Run Python code analyzers') {
            steps {
                script{
                    docker.image("legion/airflow-pipeline-agent:${Globals.buildVersion}").inside() {
                        withEnv(['PYLINTHOME=.']) {
                            sh '''
                            TERM="linux" pylint --exit-zero --output-format=parseable --reports=no legion_airflow/legion_airflow > legion-pylint.log
                            TERM="linux" pylint --exit-zero --output-format=parseable --reports=no  tests/robot/libraries/legion_airflow_test/legion_airflow_test >> legion-pylint.log
                            '''

                            archiveArtifacts 'legion-pylint.log'
                            step([
                                $class                     : 'WarningsPublisher',
                                parserConfigurations       : [[
                                                                    parserName: 'PYLint',
                                                                    pattern   : 'legion-pylint.log'
                                                            ]],
                                unstableTotalAll           : '1',
                                usePreviousBuildAsReference: true
                            ])
                        }
                    }
                }
            }
        }

        stage("Build Ansible Docker image") {
            steps {
                script {
                    legion.buildLegionImage('k8s-airflow-ansible', '.', 'containers/ansible/Dockerfile')
                }
            }
        }
        stage("Build Airflow Docker image") {
            steps {
                script {
                    legion.buildLegionImage('k8s-airflow', '.', 'containers/airflow/Dockerfile')
                }
            }
        }

        stage('Package and upload helm charts'){
            steps {
                script {
                    docker.image("legion/airflow-pipeline-agent:${Globals.buildVersion}").inside("-v /var/run/docker.sock:/var/run/docker.sock -u root") {
                        legion.uploadHelmCharts(env.pathToCharts)
                    }
                }
            }
        }

        stage("Push Docker Images") {
            parallel {
                stage('Upload Ansible Docker Image') {
                    steps {
                        script {
                            legion.uploadDockerImage('k8s-airflow-ansible')
                        }
                    }
                }
                stage('Upload Airflow Docker image') {
                    steps {
                        script {
                            legion.uploadDockerImage('k8s-airflow')
                        }
                    }
                }
            }
        }

        stage("Update Legion version string") {
            steps {
                script {
                    if (env.param_stable_release.toBoolean() && env.param_update_version_string.toBoolean()) {
                        legion.updateVersionString(env.versionFile)
                    }
                    else {
                        print("Skipping version string update")
                    }
                }
            }
        }

        stage('Update Master branch'){
            steps {
                script {
                    if (env.param_update_master.toBoolean()){
                        legion.updateMasterBranch()
                    }
                    else {
                        print("Skipping Master branch update")
                    }
                }
            }
        }

    }
    post {
        always {
            script {
                dir ("${WORKSPACE}/legion") {
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false
                        legion = load "${env.legionSharedLibPath}"
                    }
                legion.notifyBuild(currentBuild.currentResult)
            }
            deleteDir()
        }
    }
}