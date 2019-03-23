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
            sharedLibPath = "deploy/Pipeline.groovy"
            legionSharedLibPath = "deploy/legionPipeline.groovy"
    }

    stages {
        stage('Checkout and set build vars') {
            steps {
                cleanWs()
                checkout scm
                script {
                    sh 'echo RunningOn: $(curl http://checkip.amazonaws.com/)'

                    // Import legion-airflow components
                    legionAirflow = load "${env.sharedLibPath}"

                    // import Legion components
                    dir("${WORKSPACE}/legion") {
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_repo}"]], branches: [[name: "refs/tags/${env.param_legion_version_tag}"]]], poll: false
                        legion = load "${env.legionSharedLibPath}"
                    }

                    //Generate build description
                    legion.buildDescription()

                    Globals.rootCommit = sh returnStdout: true, script: 'git rev-parse --short HEAD 2> /dev/null | sed  "s/\\(.*\\)/\\1/"'
                    Globals.rootCommit = Globals.rootCommit.trim()
                    println("Root commit: " + Globals.rootCommit)

                    def dateFormat = new SimpleDateFormat("yyyyMMddHHmmss")
                    def date = new Date()
                    def buildDate = dateFormat.format(date)

                    Globals.dockerCacheArg = (env.param_enable_docker_cache.toBoolean()) ? '' : '--no-cache'
                    println("Docker cache args: " + Globals.dockerCacheArg)

                    wrap([$class: 'BuildUser']) {
                        BUILD_USER = binding.hasVariable('BUILD_USER') ? '${BUILD_USER}' : "null"
                    }

                    Globals.dockerLabels = "--label git_revision=${Globals.rootCommit} --label build_id=${env.BUILD_NUMBER} --label build_user='${BUILD_USER}' --label build_date=${buildDate}"
                    println("Docker labels: " + Globals.dockerLabels)

                    print("Check code for security issues")
                    sh "bash install-git-secrets-hook.sh install_hooks && git secrets --scan -r"

                    /// Define build version
                    if (env.param_stable_release) {
                        if (env.param_release_version ){
                            Globals.buildVersion = sh returnStdout: true, script: "python tools/update_version_id  --build-version=${env.param_release_version} legion_airflow/legion_airflow/version.py ${env.BUILD_NUMBER} '${BUILD_USER}'"
                        } else {
                            print('Error: ReleaseVersion parameter must be specified for stable release')
                            exit 1
                        }
                    } else {
                        Globals.buildVersion = sh returnStdout: true, script: "python tools/update_version_id  legion_airflow/legion_airflow/version.py ${env.BUILD_NUMBER} '${BUILD_USER}'"
                    }

                    Globals.buildVersion = Globals.buildVersion.replaceAll("\n", "")

                    env.BuildVersion = Globals.buildVersion

                    currentBuild.description = "${Globals.buildVersion} ${env.param_git_branch}"
                    print("Build version " + Globals.buildVersion)
                    print('Building shared artifact')
                    envFile = 'file.env'
                    sh """
                    rm -f $envFile
                    touch $envFile
                    echo "LEGION_AIRFLOW_VERSION=${Globals.buildVersion}" >> $envFile
                    """
                    archiveArtifacts envFile
                    sh "rm -f $envFile"
                }
            }
        }

        // Set Git Tag in case of stable release
        stage('Set GIT release Tag'){
            steps {
                script {
                    if (env.param_stable_release) {
                        if (env.param_push_git_tag.toBoolean()){
                            print('Set Release tag')
                            sshagent(["${env.param_git_deploy_key}"]) {
                                sh """
                                if [ `git tag |grep -x ${env.param_release_version}` ]; then
                                    if [ ${env.param_force_tag_push} = "true" ]; then
                                        echo 'Removing existing git tag'
                                        git tag -d ${env.param_release_version}
                                        git push origin :refs/tags/${env.param_release_version}
                                    else
                                        echo 'Specified tag already exists!'
                                        exit 1
                                    fi
                                fi
                                git tag ${env.param_release_version}
                                git push origin ${env.param_release_version}
                                """
                            }
                        } else {
                            print("Skipping release git tag push")
                        }
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
                    legion.buildLegionImage('airflow-docker-agent', '.', 'k8s/agent/Dockerfile')
                    legion.uploadDockerImage('airflow-docker-agent')
                }
            }
        }

        stage('Run Python code analyzers') {
            steps {
                script{
                    docker.image("legion/airflow-docker-agent:${Globals.buildVersion}").inside() {
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
                    legion.buildLegionImage('k8s-airflow-ansible', '.', 'k8s/ansible/Dockerfile')
                }
            }
        }
        stage("Build Airflow Docker image") {
            steps {
                script {
                    legion.buildLegionImage('k8s-airflow', '.', 'k8s/airflow/Dockerfile')
                }
            }
        }
        stage('Package and upload helm charts'){
            steps {
                script {
                    docker.image("legion/airflow-docker-agent:${Globals.buildVersion}").inside("-v /var/run/docker.sock:/var/run/docker.sock -u root") {
                        dir ("${WORKSPACE}/deploy/helms") {
                            sh"""
                                export HELM_HOME="\$(pwd)"
                                helm init --client-only
                                helm dependency update airflow
                                helm package --version "${Globals.buildVersion}" airflow
                        
                            """
                        }
                        withCredentials([[
                        $class: 'UsernamePasswordMultiBinding',
                        credentialsId: 'nexus-local-repository',
                        usernameVariable: 'USERNAME',
                        passwordVariable: 'PASSWORD']]) {
                            dir ("${WORKSPACE}/deploy/helms") {
                                script {
                                    sh"""
                                    curl -u ${USERNAME}:${PASSWORD} ${env.param_helm_repository} \
                                            --upload-file airflow-${Globals.buildVersion}.tgz
                                    """
                                }
                            }
                        }

                        if (env.param_stable_release) {
                            //checkout repo with existing charts  (needed for generating correct repo index file )
                            sshagent(["${env.param_git_deploy_key}"]) {
                                sh """
                                # Checkout helm charts repo

                                mkdir ~/.ssh || true
                                ssh-keyscan github.com >> ~/.ssh/known_hosts
                                git clone ${env.param_helm_repo_git_url} && cd ${WORKSPACE}/legion-helm-charts
                                git checkout ${env.param_helm_repo_git_branch}

                                # Move packed charts to helm repo directory

                                mv ${WORKSPACE}/deploy/helms/airflow-${Globals.buildVersion}.tgz ${WORKSPACE}/legion-helm-charts/airflow/
                                git add airflow/airflow-${Globals.buildVersion}.tgz

                                # Push charts to the repo

                                helm repo index ./
                                git add index.yaml
                                git status
                                git -c user.name='Jenkins CI' -c user.email='jenkins@legion.ci' commit -m "Release ${Globals.buildVersion}"
                                git push origin ${env.param_helm_repo_git_branch}
                                """

                            }
                        }
                        
                        // Cleanup directory
                        sh """
                        rm -rf ${WORKSPACE}/legion-helm-charts
                        rm -rf ${WORKSPACE}/deploy/helms
                        """
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
        stage("CI Stage") {
            steps {
                script {
                    if (env.param_stable_release) {
                        stage('Update Legion version string'){
                            //Update version.py file in legion package with new version string
                            if (env.param_update_version_string.toBoolean()){
                                print('Update Legion package version string')
                                if (env.param_next_version){
                                    sshagent(["${env.param_git_deploy_key}"]) {
                                        sh """
                                        git reset --hard
                                        git checkout develop
                                        sed -i -E "s/__version__.*/__version__ = \'${nextVersion}\'/g" legion_airflow/version.py
                                        git commit -a -m "Bump Legion version to ${nextVersion}" && git push origin develop
                                        """
                                    }
                                } else {
                                    throw new Exception("next_version must be specified with update_version_string parameter")
                                }
                            }
                            else {
                                print("Skipping version string update")
                            }
                        }

                        stage('Update Master branch'){
                            if (env.param_update_master.toBoolean()){
                                sshagent(["${env.param_git_deploy_key}"]) {
                                    sh """
                                    git reset --hard
                                    git checkout develop
                                    git checkout master && git pull -r origin master
                                    git pull -r origin develop
                                    git push origin master
                                    """
                                }
                            }
                            else {
                                print("Skipping Master branch update")
                            }
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                dir ("${WORKSPACE}/legion") {
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_repo}"]], branches: [[name: "refs/tags/${env.param_legion_version_tag}"]]], poll: false
                        legion = load "${env.legionSharedLibPath}"
                    }
                legion.notifyBuild(currentBuild.currentResult)
            }
            deleteDir()
        }
    }
}