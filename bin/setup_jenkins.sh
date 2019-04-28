#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
oc new-app \
jenkins-persistent
--param MEMORY_LIMIT=2Gi \
--param VOLUME_CAPACITY=4Gi \
--param DISABLE_ADMINISTRATIVE_MONITORS=true \
--namespace $GUID-jenkins

# Create custom agent container image with skopeo
echo "
FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11
USER root
RUN yum -y install skopeo && yum clean all
USER 1001
" | oc new-build \
--name jenkins-agent-appdev \
--namespace $GUID-jenkins \
--dockerfile -

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
oc new-build \
$REPO \
--name tasks-pipeline \
--strategy pipeline \
--context-dir openshift-tasks \
--env GUID=$GUID \
--env REPO=$REPO \
--env CLUSTER=$CLUSTER \
--namespace $GUID-jenkins

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
