#!/bin/bash
#Value check

if [ -z "$1" ]
then
      echo "ERROR: Application Name is empty, please add an application name as the second variable passed with the script."
      exit 1
else
      echo "Using application name $1"
fi

if [ -z "$2" ]
then
      echo "Namespace is empty, defaulting to default namespace."
fi
namespace="${2:-default}"
echo "Using namespace $namespace"
applicationName=$1
cd /workspaces/homelab

if [ -d kubernetes/apps/$namespace ]
then
    echo "$namespace exists"
else
    mkdir kubernetes/apps/$namespace/
fi

if [ -d kubernetes/apps/$namespace/$applicationName ]
then
    echo "Check application name $applicationName, this already exists!!!"
else
    mkdir kubernetes/apps/$namespace/$applicationName
fi

cd kubernetes/apps/$namespace/

ksPath="- ./"$applicationName"/ks.yaml"
if [ -e kustomization.yaml ]
then
    echo -e "  $ksPath" >> kustomization.yaml
    echo "Value added to kustomization.yaml"
else

    cat <<EOF > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $namespace
components:
  - ../../components/common
resources:
  - ./$applicationName/ks.yaml
EOF
fi

# if [ -e namespace.yaml ]
# then
#     echo "Namespace.yaml exists..."
# else
#     echo "Creating namespace.yaml"

#     cat <<EOF > namespace.yaml
# apiVersion: v1
# kind: Namespace
# metadata:
#     name: $namespace
#     labels:
#         kustomize.toolkit.fluxcd.io/prune: disabled
# EOF
# fi

cd $applicationName

if [ -e ks.yaml ]
then
    echo "ks.yaml exists, skipping"
else
    echo "Creating ks.yaml"
    cat << EOF > ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app $applicationName
  namespace: $namespace
spec:
  targetNamespace: $namespace
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  path: ./kubernetes/apps/$namespace/$applicationName/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  wait: true
  interval: 30m
  retryInterval: 3m
  timeout: 2m
  postBuild:
    substitute:
      APP: *app
      VOLSYNC_CAPACITY: 1Gi
EOF
fi

if [ -d app ]
then
    echo "app exists, skipping"
else
    echo "Creating app folder"
    mkdir app
fi

cd app

if [ -e helmrelease.yaml ]
then
    echo "helmrelease.yaml exists, skipping"
else
    echo "Creating helmrelease.yaml with default values.... please fill out spec after script finishes."
    cat << EOF > helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: $applicationName
  namespace: $namespace
spec:
  chartRef:
    kind: OCIRepository
    name: app-template
  interval: 30m0s
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  uninstall:
    keepHistory: false
EOF
fi

if [ -e kustomization.yaml ]
then
    echo "kustomization.yaml exists, skipping"
else
    echo "Creating kustomization.yaml"
    cat << EOF > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
 - ./helmrelease.yaml
EOF
fi

echo "Done. Please verify values in app/helmrelease.yaml and verify repository is ready to go."
echo "After this, commit changes and push to remote"
