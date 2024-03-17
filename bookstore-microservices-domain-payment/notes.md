# How to create helm chart
  (DO NOT USE _ IN THE NAME BECAUSE IT IS FORBIDDEN, instead use - or .)
```shell
mkdir helm
cd helm 
helm create micro-payment
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
    port: 80
readinessProbe:
  httpGet:
    path: /actuator/health
    #inside container, not via the service
    port: 80
```




## In values.yaml, set docker image and tag name to use for Helm chart
```
image:
repository: xiaoouit/hu-csm-thesis
# Overrides the image tag whose default is the chart appVersion.
tag: "micro-payment"
```


## create configmap, using bookstore.yaml pament configmap and adding db settings + liquibase
```yaml
apiVersion: v1
data:
  application.yaml: |-
    spring:
      datasource:
        url: {{ .Values.db.url }}
        username: {{ .Values.db.username }}
        password: {{ .Values.db.password }}
        initialization-mode: always
      liquibase:
        enabled: true
        changeLog: classpath:/db/changelog/db.changelog-master.xml
      jpa:
        show-sql: false
        hibernate:
          ddl-auto: none
        open-in-view: false
      resources:
        chain:
          compressed: true
          cache: true
        cache:
          period: 86400

    security:
      oauth2:
        client:
          clientId: payment
          clientSecret: payment_secret
          accessTokenUri: http://${AUTH_HOST:security}:${AUTH_PORT:80}/oauth/token
          grant-type: client_credentials
          scope: SERVICE
        resource:
          userInfoUri: BUGFIX

    logging:
      pattern:
        console: "%clr(%d{HH:mm:ss.SSS}){faint} %clr(${LOG_LEVEL_PATTERN:%5p}) %clr(-){faint} %clr([%t]){faint} %clr(%-40logger{39}){cyan}[%line]%clr(:){faint} %m%n${LOG_EXCEPTION_CONVERSION_WORD:%wEx}"
      level:
        root: INFO

    server:
      port: ${PORT:80}
kind: ConfigMap
metadata:
  name: payment

```

create db settings in values.yaml. Settings will be passed to the configmap
```yaml
db:
  url: "jdbc:mysql://my-release-mysql.default.svc.cluster.local:3306/payment?useUnicode=true&characterEncoding=utf-8"
  host: "my-release-mysql.default.svc.cluster.local"
  database: payment
  username: root
  password: should-be-set
  jobDbCreation:
    image: bitnami/mysql:8.0.36-debian-12-r8
    pullPolicy: IfNotPresent
```


## add jobs to create database during installation and remove database during uninstallation

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "micro-payment.fullname" . }}-mysql-database-creation
  labels:
    {{- include "micro-payment.labels" . | nindent 4 }}-mysql-database-creation
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "micro-payment.fullname" . }}-mysql-database-creation
      labels:
        app: {{ include "micro-payment.fullname" . }}-mysql-database-creation
    spec:
      containers:
          - name: {{ include "micro-payment.fullname" . }}-mysql-database-creation
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
  name: {{ include "micro-payment.fullname" . }}-mysql-database-deletion
  labels:
    {{- include "micro-payment.labels" . | nindent 4 }}-mysql-database-deletion
  annotations:
    "helm.sh/hook": post-delete
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "micro-payment.fullname" . }}-mysql-database-deletion
      labels:
        app: {{ include "micro-payment.fullname" . }}-mysql-database-deletion
    spec:
      containers:
          - name: {{ include "micro-payment.fullname" . }}-mysql-database-deletion
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

## create role for the service-account in order to query Kubernetes API for ressources like configmaps, .... 
Create a file role.yaml with this :
```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "micro-payment.fullname" . }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "micro-payment.fullname" . }}
subjects:
  - kind: ServiceAccount
    name: {{ include "micro-payment.serviceAccountName" . }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name:  {{ include "micro-payment.fullname" . }}
rules:
  - apiGroups:
      - ""
      - "extensions"
      - "app"
    resources:
      - namespaces
      - endpoints
      - services
      - nodes
      - nodes/proxy
      - pods
      - configmaps
    verbs:
      - list
      - get
      - watch

```

Otherwise POD will failed to start with this exception:
```
o.fabric8.kubernetes.client.KubernetesClientException: Failure executing: GET at: https://10.96.0.1/api/v1/namespaces/default/configmaps/warehouse. Message: Forbidden!Configured service account doesn't have access. Service account may have been revoked. configmaps "warehouse" is forbidden: User "system:serviceaccount:default:micro-warehouse-1710670812" cannot get resource "configmaps" in API group "" in the namespace "default".
	at io.fabric8.kubernetes.client.dsl.base.OperationSupport.requestFailure(OperationSupport.java:568) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.OperationSupport.assertResponseCode(OperationSupport.java:505) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.OperationSupport.handleResponse(OperationSupport.java:471) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.OperationSupport.handleResponse(OperationSupport.java:430) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.OperationSupport.handleGet(OperationSupport.java:395) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.OperationSupport.handleGet(OperationSupport.java:376) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.BaseOperation.handleGet(BaseOperation.java:878) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.BaseOperation.getMandatory(BaseOperation.java:249) ~[kubernetes-client-4.10.1.jar!/:na]
	at io.fabric8.kubernetes.client.dsl.base.BaseOperation.get(BaseOperation.java:203) ~[kubernetes-client-4.10.1.jar!/:na]
	at org.springframework.cloud.kubernetes.config.ConfigMapPropertySource.getData(ConfigMapPropertySource.java:95) ~[spring-cloud-kubernetes-config-1.1.2.RELEASE.jar!/:1.1.2.RELEASE]
	at org.springframework.cloud.kubernetes.config.ConfigMapPropertySource.<init>(ConfigMapPropertySource.java:76) ~[spring-cloud-kubernetes-config-1.1.2.RELEASE.jar!/:1.1.2.RELEASE]
	at org.springframework.cloud.kubernetes.config.ConfigMapPropertySourceLocator.getMapPropertySourceForSingleConfigMap(ConfigMapPropertySourceLocator.java:95) ~[spring-cloud-kubernetes-config-1.1.2.RELEASE.jar!/:1.1.2.RELEASE]
	at org.springframework.cloud.kubernetes.config.ConfigMapPropertySourceLocator.lambda$locate$0(ConfigMapPropertySourceLocator.java:78) ~[spring-cloud-kubernetes-config-1.1.2.RELEASE.jar!/:1.1.2.RELEASE]
	at java.base/java.util.ArrayList.forEach(ArrayList.java:1540) ~[na:na]
	at org.springframework.cloud.kubernetes.config.ConfigMapPropertySourceLocator.locate(ConfigMapPropertySourceLocator.java:77) ~[spring-cloud-kubernetes-config-1.1.2.RELEASE.jar!/:1.1.2.RELEASE]
	at org.springframework.cloud.bootstrap.config.PropertySourceLocator.locateCollection(PropertySourceLocator.java:52) ~[spring-cloud-context-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.cloud.bootstrap.config.PropertySourceLocator.locateCollection(PropertySourceLocator.java:47) ~[spring-cloud-context-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.cloud.bootstrap.config.PropertySourceBootstrapConfiguration.initialize(PropertySourceBootstrapConfiguration.java:97) ~[spring-cloud-context-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.boot.SpringApplication.applyInitializers(SpringApplication.java:626) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.prepareContext(SpringApplication.java:370) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.run(SpringApplication.java:314) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.run(SpringApplication.java:1226) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.run(SpringApplication.java:1215) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at com.github.fenixsoft.bookstore.warehouse.WarehouseApplication.main(WarehouseApplication.java:33) ~[classes!/:1.0.0-SNAPSHOT]
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method) ~[na:na]
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62) ~[na:na]
	at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43) ~[na:na]
	at java.base/java.lang.reflect.Method.invoke(Method.java:567) ~[na:na]
	at org.springframework.boot.loader.MainMethodRunner.run(MainMethodRunner.java:48) ~[bookstore-warehouse.jar:1.0.0-SNAPSHOT]
	at org.springframework.boot.loader.Launcher.launch(Launcher.java:87) ~[bookstore-warehouse.jar:1.0.0-SNAPSHOT]
	at org.springframework.boot.loader.Launcher.launch(Launcher.java:51) ~[bookstore-warehouse.jar:1.0.0-SNAPSHOT]
	at org.springframework.boot.loader.JarLauncher.main(JarLauncher.java:52) ~[bookstore-warehouse.jar:1.0.0-SNAPSHOT]

```


## create image and load it to the minikube registry

note: first needs to disable liquibase for the tests otherwhise there will be error. Edit application-test.yaml with:
```yaml
spring:
  liquibase:
    enabled: false
```

```shell
make image
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

 