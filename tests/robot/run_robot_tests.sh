#!/bin/bash
set -e
vault=/tmp/vaultfile

echo "Starting robot tests"
cd tests/robot 

[[ -z "$2" ]] &&  echo "Missed arguments! Usage: run_robot_tests.sh PROFILE LEGION_VERSION" && exit 1

# Set required variables
export PROFILE=$1
export LEGION_VERSION=$2
export PATH_TO_PROFILES_DIR="../../legion/deploy/profiles"
export PATH_TO_PROFILE_FILE="$PATH_TO_PROFILES_DIR/$PROFILE.yml"
export PATH_TO_COOKIES="$PATH_TO_PROFILES_DIR/cookies.dat"
export CLUSTER_NAME=$PROFILE
export CLUSTER_STATE_STORE="$(yq -r .state_store $PATH_TO_PROFILE_FILE)"
export CREDENTIAL_SECRETS="$PROFILE.yaml"

# Get cluster auth data
aws s3 cp $CLUSTER_STATE_STORE/vault/$PROFILE $CLUSTER_NAME
ansible-vault decrypt --vault-password-file=$vault --output $CREDENTIAL_SECRETS $CLUSTER_NAME

# Run Robot tests
pabot --verbose --processes 6 --variable PATH_TO_PROFILES_DIR:$PATH_TO_PROFILES_DIR --listener legion_airflow_test.process_reporter --outputdir . tests/airflow.robot
