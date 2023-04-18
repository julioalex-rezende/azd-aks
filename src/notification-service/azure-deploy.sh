#!/bin/sh

# Pass in the ACR registry name as the first argument
ACR_NAME=$1

serviceName="notification-service"
version=$(date +%Y.%m.%d.%H.%M.%S)
printf "\n🛖  Releasing version: %s\n\n" "${version}"

printf "\n☢️  Attempting to delete existing deployment %s\n\n" "${serviceName}"
kubectl delete deployment "${serviceName}" --ignore-not-found=true

printf "\n🏗️  Building docker image\n\n"
docker build -t "${ACR_NAME}.azurecr.io/${serviceName}":"${version}" .

printf "\n🚚  Pushing docker image to local registry\n\n"
az acr login --name "${ACR_NAME}"
docker push "${ACR_NAME}.azurecr.io/${serviceName}":"${version}"

printf "\n🚀  Deploying to cluster\n\n"
cat <<EOF | kubectl apply -f -

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${serviceName}
  labels:
    app: ${serviceName}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${serviceName}
  template:
    metadata:
      labels:
        app: ${serviceName}
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "${serviceName}"
        dapr.io/app-port: "8080"
        dapr.io/enable-api-logging: "true"
    spec:
      containers:
      - name: node
        image: ${ACR_NAME}.azurecr.io/${serviceName}:${version}
        env:
        - name: APP_PORT
          value: "8080"
        - name: APP_VERSION
          value: "${version}"
        ports:
        - containerPort: 80
        imagePullPolicy: Always
EOF


printf "\n🎉  Deployment complete\n\n"