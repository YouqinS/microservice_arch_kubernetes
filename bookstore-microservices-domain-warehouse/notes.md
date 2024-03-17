# How to create helm chart
  (DO NOT USE _ IN THE NAME BECAUSE IT IS FORBIDDEN, instead use - or .)
```shell
mkdir helm
cd helm 
helm create micro-warehouse
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
tag: "micro-warehouse"
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
  name: {{ include "micro-warehouse.fullname" . }}
  labels:
    {{- include "micro-warehouse.labels" . | nindent 4 }}
```

create db settings in values.yaml. Settings will be passed to the configmap
```yaml
db:
  url: "jdbc:mysql://my-release-mysql.default.svc.cluster.local:3306/warehouse?useUnicode=true&characterEncoding=utf-8"
  host: "my-release-mysql.default.svc.cluster.local"
  database: warehouse
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
                name: {{ include "micro-warehouse.fullname" . }}

```

## add jobs to create database during installation and remove database during uninstallation

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "micro-warehouse.fullname" . }}-mysql-database-creation
  labels:
    {{- include "micro-warehouse.labels" . | nindent 4 }}-mysql-database-creation
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "micro-warehouse.fullname" . }}-mysql-database-creation
      labels:
        app: {{ include "micro-warehouse.fullname" . }}-mysql-database-creation
    spec:
      containers:
        - name: {{ include "micro-warehouse.fullname" . }}-mysql-database-creation
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
  name: {{ include "micro-warehouse.fullname" . }}-mysql-database-deletion
  labels:
    {{- include "micro-warehouse.labels" . | nindent 4 }}-mysql-database-deletion
  annotations:
    "helm.sh/hook": post-delete
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "micro-warehouse.fullname" . }}-mysql-database-deletion
      labels:
        app: {{ include "micro-warehouse.fullname" . }}-mysql-database-deletion
    spec:
      containers:
        - name: {{ include "micro-warehouse.fullname" . }}-mysql-database-deletion
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
name: {{ include "micro-warehouse.fullname" . }}
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: Role
name: {{ include "micro-warehouse.fullname" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "micro-warehouse.serviceAccountName" . }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
name:  {{ include "micro-warehouse.fullname" . }}
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


## CONFIGMAP SHOULD BE CHANGED TO HAVE EXACT SETTINGS FROM bookstore.yaml (warehouse configmap)
dockerfile should have :
```dockerfile
    PROFILES="default"
```

New Configmap should be created (and old one removed from pod) based on bookstore.yaml (warehouse configmap) (with liquibase and datasource properties added):
```yaml
apiVersion: v1
data:
  application.yaml: |-
    database: mysql  
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
          clientId: warehouse
          clientSecret: warehouse_secret
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
  name: warehouse
```


Otherwise the POD will crash with this error:
```
    ______           _         ____              __  _____ __
   / ____/__  ____  (_)  __   / __ )____  ____  / /_/ ___// /_____  ________
  / /_  / _ \/ __ \/ / |/_/  / __  / __ \/ __ \/ __/\__ \/ __/ __ \/ ___/ _ \
 / __/ /  __/ / / / />  <   / /_/ / /_/ / /_/ / /_ ___/ / /_/ /_/ / /  /  __/
/_/    \___/_/ /_/_/_/|_|  /_____/\____/\____/\__//____/\__/\____/_/   \___/
                                                          Warehouse Domain

2024-03-17 10:44:11.544  INFO 1 --- [           main] b.c.PropertySourceBootstrapConfiguration : Located property source: [BootstrapPropertySource {name='bootstrapProperties-configmap.warehouse.default'}]
2024-03-17 10:44:11.561  INFO 1 --- [           main] c.g.f.b.warehouse.WarehouseApplication   : The following profiles are active: kubernetes,mysql
2024-03-17 10:44:12.827  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Bootstrapping Spring Data JPA repositories in DEFAULT mode.
2024-03-17 10:44:12.953  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Finished Spring Data repository scanning in 111ms. Found 3 JPA repository interfaces.
2024-03-17 10:44:13.106  WARN 1 --- [           main] o.s.boot.actuate.endpoint.EndpointId     : Endpoint ID 'service-registry' contains invalid characters, please migrate to a valid format.
2024-03-17 10:44:13.441  INFO 1 --- [           main] o.s.cloud.context.scope.GenericScope     : BeanFactory id=1276b808-7103-355d-9f5f-805809c91b0c
2024-03-17 10:44:13.732  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'com.github.fenixsoft.bookstore.domain.security.AccountServiceClient' of type [org.springframework.cloud.openfeign.FeignClientFactoryBean] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.898  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.config.annotation.configuration.ObjectPostProcessorConfiguration' of type [org.springframework.security.config.annotation.configuration.ObjectPostProcessorConfiguration] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.907  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'objectPostProcessor' of type [org.springframework.security.config.annotation.configuration.AutowireBeanFactoryObjectPostProcessor] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.911  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler@60e949e1' of type [org.springframework.security.oauth2.provider.expression.OAuth2MethodSecurityExpressionHandler] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.912  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.config.annotation.method.configuration.GlobalMethodSecurityConfiguration' of type [org.springframework.security.config.annotation.method.configuration.GlobalMethodSecurityConfiguration] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.918  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.config.annotation.method.configuration.Jsr250MetadataSourceConfiguration' of type [org.springframework.security.config.annotation.method.configuration.Jsr250MetadataSourceConfiguration] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.919  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'jsr250MethodSecurityMetadataSource' of type [org.springframework.security.access.annotation.Jsr250MethodSecurityMetadataSource] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.920  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'methodSecurityMetadataSource' of type [org.springframework.security.access.method.DelegatingMethodSecurityMetadataSource] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:14.364  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2024-03-17 10:44:14.381  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2024-03-17 10:44:14.381  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.33]
2024-03-17 10:44:14.480  INFO 1 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2024-03-17 10:44:14.480  INFO 1 --- [           main] o.s.web.context.ContextLoader            : Root WebApplicationContext: initialization completed in 2880 ms
2024-03-17 10:44:15.077  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Starting...
youqin@youqin-Latitude-7490:~/Downloads/CSM_HU/_thesis/projects/bookstore/microservice_arch_kubernetes/bookstore-microservices-library-infrastructure$ kubectl logs micro-warehouse-1710672183-574cdf776-xnhb8
    ______           _         ____              __  _____ __
   / ____/__  ____  (_)  __   / __ )____  ____  / /_/ ___// /_____  ________
  / /_  / _ \/ __ \/ / |/_/  / __  / __ \/ __ \/ __/\__ \/ __/ __ \/ ___/ _ \
 / __/ /  __/ / / / />  <   / /_/ / /_/ / /_/ / /_ ___/ / /_/ /_/ / /  /  __/
/_/    \___/_/ /_/_/_/|_|  /_____/\____/\____/\__//____/\__/\____/_/   \___/
                                                          Warehouse Domain

2024-03-17 10:44:11.544  INFO 1 --- [           main] b.c.PropertySourceBootstrapConfiguration : Located property source: [BootstrapPropertySource {name='bootstrapProperties-configmap.warehouse.default'}]
2024-03-17 10:44:11.561  INFO 1 --- [           main] c.g.f.b.warehouse.WarehouseApplication   : The following profiles are active: kubernetes,mysql
2024-03-17 10:44:12.827  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Bootstrapping Spring Data JPA repositories in DEFAULT mode.
2024-03-17 10:44:12.953  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Finished Spring Data repository scanning in 111ms. Found 3 JPA repository interfaces.
2024-03-17 10:44:13.106  WARN 1 --- [           main] o.s.boot.actuate.endpoint.EndpointId     : Endpoint ID 'service-registry' contains invalid characters, please migrate to a valid format.
2024-03-17 10:44:13.441  INFO 1 --- [           main] o.s.cloud.context.scope.GenericScope     : BeanFactory id=1276b808-7103-355d-9f5f-805809c91b0c
2024-03-17 10:44:13.732  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'com.github.fenixsoft.bookstore.domain.security.AccountServiceClient' of type [org.springframework.cloud.openfeign.FeignClientFactoryBean] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.898  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.config.annotation.configuration.ObjectPostProcessorConfiguration' of type [org.springframework.security.config.annotation.configuration.ObjectPostProcessorConfiguration] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.907  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'objectPostProcessor' of type [org.springframework.security.config.annotation.configuration.AutowireBeanFactoryObjectPostProcessor] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.911  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.access.expression.method.DefaultMethodSecurityExpressionHandler@60e949e1' of type [org.springframework.security.oauth2.provider.expression.OAuth2MethodSecurityExpressionHandler] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.912  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.config.annotation.method.configuration.GlobalMethodSecurityConfiguration' of type [org.springframework.security.config.annotation.method.configuration.GlobalMethodSecurityConfiguration] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.918  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'org.springframework.security.config.annotation.method.configuration.Jsr250MetadataSourceConfiguration' of type [org.springframework.security.config.annotation.method.configuration.Jsr250MetadataSourceConfiguration] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.919  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'jsr250MethodSecurityMetadataSource' of type [org.springframework.security.access.annotation.Jsr250MethodSecurityMetadataSource] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:13.920  INFO 1 --- [           main] trationDelegate$BeanPostProcessorChecker : Bean 'methodSecurityMetadataSource' of type [org.springframework.security.access.method.DelegatingMethodSecurityMetadataSource] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)
2024-03-17 10:44:14.364  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2024-03-17 10:44:14.381  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2024-03-17 10:44:14.381  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.33]
2024-03-17 10:44:14.480  INFO 1 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2024-03-17 10:44:14.480  INFO 1 --- [           main] o.s.web.context.ContextLoader            : Root WebApplicationContext: initialization completed in 2880 ms
2024-03-17 10:44:15.077  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Starting...
2024-03-17 10:44:15.608  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Start completed.
2024-03-17 10:44:16.277  INFO 1 --- [           main] liquibase.lockservice                    : Successfully acquired change log lock
2024-03-17 10:44:17.563  INFO 1 --- [           main] liquibase.changelog                      : Reading from warehouse.DATABASECHANGELOG
2024-03-17 10:44:17.706  INFO 1 --- [           main] liquibase.lockservice                    : Successfully released change log lock
2024-03-17 10:44:17.831  INFO 1 --- [           main] o.hibernate.jpa.internal.util.LogHelper  : HHH000204: Processing PersistenceUnitInfo [name: default]
2024-03-17 10:44:17.936  INFO 1 --- [           main] org.hibernate.Version                    : HHH000412: Hibernate ORM core version 5.4.12.Final
2024-03-17 10:44:18.098  INFO 1 --- [           main] o.hibernate.annotations.common.Version   : HCANN000001: Hibernate Commons Annotations {5.1.0.Final}
2024-03-17 10:44:18.238  INFO 1 --- [           main] org.hibernate.dialect.Dialect            : HHH000400: Using dialect: org.hibernate.dialect.MySQL8Dialect
2024-03-17 10:44:19.080  INFO 1 --- [           main] o.h.e.t.j.p.i.JtaPlatformInitiator       : HHH000490: Using JtaPlatform implementation: [org.hibernate.engine.transaction.jta.platform.internal.NoJtaPlatform]
2024-03-17 10:44:19.091  INFO 1 --- [           main] j.LocalContainerEntityManagerFactoryBean : Initialized JPA EntityManagerFactory for persistence unit 'default'
2024-03-17 10:44:19.672  WARN 1 --- [           main] JpaBaseConfiguration$JpaWebConfiguration : spring.jpa.open-in-view is enabled by default. Therefore, database queries may be performed during view rendering. Explicitly configure spring.jpa.open-in-view to disable this warning
2024-03-17 10:44:19.728  WARN 1 --- [           main] ConfigServletWebServerApplicationContext : Exception encountered during context initialization - cancelling refresh attempt: org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'JWTAccessTokenService' defined in URL [jar:file:/bookstore-warehouse.jar!/BOOT-INF/lib/bookstore-microservices-library-infrastructure-1.0.0-SNAPSHOT.jar!/com/github/fenixsoft/bookstore/infrastructure/security/JWTAccessTokenService.class]: Unsatisfied dependency expressed through constructor parameter 0; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'JWTAccessToken' defined in URL [jar:file:/bookstore-warehouse.jar!/BOOT-INF/lib/bookstore-microservices-library-infrastructure-1.0.0-SNAPSHOT.jar!/com/github/fenixsoft/bookstore/infrastructure/security/JWTAccessToken.class]: Unsatisfied dependency expressed through constructor parameter 0; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'authenticAccountDetailsService': Unsatisfied dependency expressed through field 'accountRepository'; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'authenticAccountRepository': Unsatisfied dependency expressed through field 'userService'; nested exception is org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'com.github.fenixsoft.bookstore.domain.security.AccountServiceClient': FactoryBean threw exception on object creation; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'feignConfiguration': Unsatisfied dependency expressed through field 'resource'; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'resourceServerConfiguration': Unsatisfied dependency expressed through field 'tokenService'; nested exception is org.springframework.beans.factory.BeanCurrentlyInCreationException: Error creating bean with name 'JWTAccessTokenService': Requested bean is currently in creation: Is there an unresolvable circular reference?
2024-03-17 10:44:19.731  INFO 1 --- [           main] j.LocalContainerEntityManagerFactoryBean : Closing JPA EntityManagerFactory for persistence unit 'default'
2024-03-17 10:44:19.732  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown initiated...
2024-03-17 10:44:19.747  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Shutdown completed.
2024-03-17 10:44:19.749  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Stopping service [Tomcat]
2024-03-17 10:44:19.772  INFO 1 --- [           main] ConditionEvaluationReportLoggingListener : 

Error starting ApplicationContext. To display the conditions report re-run your application with 'debug' enabled.
2024-03-17 10:44:19.776 ERROR 1 --- [           main] o.s.b.d.LoggingFailureAnalysisReporter   : 

***************************
APPLICATION FAILED TO START
***************************

Description:

The dependencies of some of the beans in the application context form a cycle:

┌─────┐
|  JWTAccessTokenService defined in URL [jar:file:/bookstore-warehouse.jar!/BOOT-INF/lib/bookstore-microservices-library-infrastructure-1.0.0-SNAPSHOT.jar!/com/github/fenixsoft/bookstore/infrastructure/security/JWTAccessTokenService.class]
↑     ↓
|  JWTAccessToken defined in URL [jar:file:/bookstore-warehouse.jar!/BOOT-INF/lib/bookstore-microservices-library-infrastructure-1.0.0-SNAPSHOT.jar!/com/github/fenixsoft/bookstore/infrastructure/security/JWTAccessToken.class]
↑     ↓
|  authenticAccountDetailsService (field private com.github.fenixsoft.bookstore.domain.security.AuthenticAccountRepository com.github.fenixsoft.bookstore.domain.security.AuthenticAccountDetailsService.accountRepository)
↑     ↓
|  authenticAccountRepository (field private com.github.fenixsoft.bookstore.domain.security.AccountServiceClient com.github.fenixsoft.bookstore.domain.security.AuthenticAccountRepository.userService)
↑     ↓
|  com.github.fenixsoft.bookstore.domain.security.AccountServiceClient
↑     ↓
|  feignConfiguration (field private org.springframework.security.oauth2.client.token.grant.client.ClientCredentialsResourceDetails com.github.fenixsoft.bookstore.infrastructure.configuration.FeignConfiguration.resource)
↑     ↓
|  resourceServerConfiguration (field private com.github.fenixsoft.bookstore.infrastructure.security.JWTAccessTokenService com.github.fenixsoft.bookstore.infrastructure.configuration.ResourceServerConfiguration.tokenService)
└─────┘


```

## change probes port to 80
In values.yaml port should be changed to 80 instead of 8080
otherwise error:
```
  Warning  Unhealthy  7s (x3 over 16s)  kubelet            Readiness probe failed: Get "http://10.244.0.171:8080/actuator/health": dial tcp 10.244.0.171:8080: connect: connection refused
  Warning  Unhealthy  7s                kubelet            Liveness probe failed: Get "http://10.244.0.171:8080/actuator/health": dial tcp 10.244.0.171:8080: connect: connection refused

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

 