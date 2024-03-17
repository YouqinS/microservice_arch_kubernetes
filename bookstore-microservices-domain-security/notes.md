# How to create helm chart
  (DO NOT USE _ IN THE NAME BECAUSE IT IS FORBIDDEN, instead use - or .)
```shell
mkdir helm
cd helm 
helm create micro-security
```


## fix probes otherwise pod will keep restarting
```text
Warning  Unhealthy  70s (x12 over 2m7s)  kubelet            Readiness probe failed: Get "http://10.244.0.158:80/": dial tcp 10.244.0.158:80: connect: connection refused
Warning  Unhealthy  70s (x6 over 2m)     kubelet            Liveness probe failed: Get "http://10.244.0.158:80/": dial tcp 10.244.0.158:80: connect: connection refused
```
Need to edit values.yaml:
```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    #inside container, not via the service
    port: 8080
readinessProbe:
  httpGet:
    path: /actuator/health
    #inside container, not via the service
    port: 8080
```




## In values.yaml, set docker image and tag name to use for Helm chart
```
image:
repository: xiaoouit/hu-csm-thesis
# Overrides the image tag whose default is the chart appVersion.
tag: "micro-security"
```


## create configmap for db settings and set it to pod
```yaml
apiVersion: v1
data:
  spring.datasource.username: {{ .Values.db.username }}
  spring.datasource.password: {{ .Values.db.password }}
  spring.datasource.url: {{ .Values.db.url }}
kind: ConfigMap
metadata:
  name: {{ include "micro-security.fullname" . }}
  labels:
    {{- include "micro-security.labels" . | nindent 4 }}
```

create db settings in values.yaml. Settings will be passed to the configmap
```yaml
db:
  url: "jdbc:mysql://my-release-mysql.default.svc.cluster.local:3306/security?useUnicode=true&characterEncoding=utf-8"
  host: "my-release-mysql.default.svc.cluster.local"
  database: security
  username: root
  password: should-be-set
  jobDbCreation:
    image: bitnami/mysql:8.0.36-debian-12-r8
    pullPolicy: IfNotPresent
```

In the deployment.yaml , for the pod add the configmap to environment variables:
```yaml
          envFrom:
            - configMapRef:
                name: {{ include "micro-security.fullname" . }}

```

## add jobs to create database during installation and remove database during uninstallation

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "micro-security.fullname" . }}-mysql-database-creation
  labels:
    {{- include "micro-security.labels" . | nindent 4 }}-mysql-database-creation
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "micro-security.fullname" . }}-mysql-database-creation
      labels:
        app: {{ include "micro-security.fullname" . }}-mysql-database-creation
    spec:
      containers:
        - name: {{ include "micro-security.fullname" . }}-mysql-database-creation
          imagePullPolicy: {{ .Values.db.jobDbCreation.pullPolicy }}
          env:
            - name: MYSQL_HOST
              value: {{ .Values.db.host }}
            - name: MYSQL_USER
              value: {{ .Values.db.username }}
            - name: MYSQL_PASSWORD
              value: {{ .Values.db.password }}
            - name: MYSQL_DATABASE
              value: {{ .Values.db.database }}
          image: {{ .Values.db.jobDbCreation.image }}
          command:
            - "bin/sh"
            - "-c"
            - 'mysql -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE $MYSQL_DATABASE  ;" '
      restartPolicy: Never
```


```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "micro-security.fullname" . }}-mysql-database-deletion
  labels:
    {{- include "micro-security.labels" . | nindent 4 }}-mysql-database-deletion
  annotations:
    "helm.sh/hook": post-delete
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "micro-security.fullname" . }}-mysql-database-deletion
      labels:
        app: {{ include "micro-security.fullname" . }}-mysql-database-deletion
    spec:
      containers:
        - name: {{ include "micro-security.fullname" . }}-mysql-database-deletion
          imagePullPolicy: {{ .Values.db.jobDbCreation.pullPolicy }}
          env:
            - name: MYSQL_HOST
              value: {{ .Values.db.host }}
            - name: MYSQL_USER
              value: {{ .Values.db.username }}
            - name: MYSQL_PASSWORD
              value: {{ .Values.db.password }}
            - name: MYSQL_DATABASE
              value: {{ .Values.db.database }}
          image: {{ .Values.db.jobDbCreation.image }}
          command:
            - "bin/sh"
            - "-c"
            - 'mysql -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD -e "DROP DATABASE $MYSQL_DATABASE  ;" '
      restartPolicy: Never
```

## Publish image to docker repository
```shell
make publish-image
```

## build and install helm chart in minikube
This will use local docker image that has been uploaded to minikube image registry
```shell
make install
```

 