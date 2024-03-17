# How to create helm chart
  (DO NOT USE _ IN THE NAME BECAUSE IT IS FORBIDDEN, instead use - or .)
```shell
mkdir helm
cd helm 
helm create micro-gateway
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



## create role for the service-account in order to query Kubernetes API for ressources like configmaps, .... 
Create a file role.yaml with this :
```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "micro-gateway.fullname" . }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "micro-gateway.fullname" . }}
subjects:
  - kind: ServiceAccount
    name: {{ include "micro-gateway.serviceAccountName" . }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name:  {{ include "micro-gateway.fullname" . }}
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
2024-03-17 12:48:00.916  INFO 1 --- [           main] c.c.c.ConfigServicePropertySourceLocator : Fetching config from server at : http://localhost:8888
2024-03-17 12:48:00.975  INFO 1 --- [           main] c.c.c.ConfigServicePropertySourceLocator : Connect Timeout Exception on Url - http://localhost:8888. Will be trying the next url if available
2024-03-17 12:48:00.980 ERROR 1 --- [           main] o.s.boot.SpringApplication               : Application run failed

java.lang.IllegalStateException: Could not locate PropertySource and the fail fast property is set, failing
	at org.springframework.cloud.config.client.ConfigServicePropertySourceLocator.locate(ConfigServicePropertySourceLocator.java:148) ~[spring-cloud-config-client-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.cloud.bootstrap.config.PropertySourceLocator.locateCollection(PropertySourceLocator.java:52) ~[spring-cloud-context-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.cloud.config.client.ConfigServicePropertySourceLocator.locateCollection(ConfigServicePropertySourceLocator.java:163) ~[spring-cloud-config-client-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.cloud.bootstrap.config.PropertySourceBootstrapConfiguration.initialize(PropertySourceBootstrapConfiguration.java:97) ~[spring-cloud-context-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.boot.SpringApplication.applyInitializers(SpringApplication.java:626) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.prepareContext(SpringApplication.java:370) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.run(SpringApplication.java:314) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.run(SpringApplication.java:1226) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at org.springframework.boot.SpringApplication.run(SpringApplication.java:1215) ~[spring-boot-2.2.6.RELEASE.jar!/:2.2.6.RELEASE]
	at com.github.fenixsoft.bookstore.gateway.GatewayApplication.main(GatewayApplication.java:19) ~[classes!/:1.0.0-SNAPSHOT]
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method) ~[na:na]
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62) ~[na:na]
	at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43) ~[na:na]
	at java.base/java.lang.reflect.Method.invoke(Method.java:567) ~[na:na]
	at org.springframework.boot.loader.MainMethodRunner.run(MainMethodRunner.java:48) ~[gateway.jar:1.0.0-SNAPSHOT]
	at org.springframework.boot.loader.Launcher.launch(Launcher.java:87) ~[gateway.jar:1.0.0-SNAPSHOT]
	at org.springframework.boot.loader.Launcher.launch(Launcher.java:51) ~[gateway.jar:1.0.0-SNAPSHOT]
	at org.springframework.boot.loader.JarLauncher.main(JarLauncher.java:52) ~[gateway.jar:1.0.0-SNAPSHOT]
Caused by: org.springframework.web.client.ResourceAccessException: I/O error on GET request for "http://localhost:8888/gateway/default": Connection refused (Connection refused); nested exception is java.net.ConnectException: Connection refused (Connection refused)
	at org.springframework.web.client.RestTemplate.doExecute(RestTemplate.java:748) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	at org.springframework.web.client.RestTemplate.execute(RestTemplate.java:674) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	at org.springframework.web.client.RestTemplate.exchange(RestTemplate.java:583) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	at org.springframework.cloud.config.client.ConfigServicePropertySourceLocator.getRemoteEnvironment(ConfigServicePropertySourceLocator.java:264) ~[spring-cloud-config-client-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	at org.springframework.cloud.config.client.ConfigServicePropertySourceLocator.locate(ConfigServicePropertySourceLocator.java:107) ~[spring-cloud-config-client-2.2.2.RELEASE.jar!/:2.2.2.RELEASE]
	... 17 common frames omitted
Caused by: java.net.ConnectException: Connection refused (Connection refused)
	at java.base/java.net.PlainSocketImpl.socketConnect(Native Method) ~[na:na]
	at java.base/java.net.AbstractPlainSocketImpl.doConnect(AbstractPlainSocketImpl.java:399) ~[na:na]
	at java.base/java.net.AbstractPlainSocketImpl.connectToAddress(AbstractPlainSocketImpl.java:242) ~[na:na]
	at java.base/java.net.AbstractPlainSocketImpl.connect(AbstractPlainSocketImpl.java:224) ~[na:na]
	at java.base/java.net.Socket.connect(Socket.java:591) ~[na:na]
	at java.base/sun.net.NetworkClient.doConnect(NetworkClient.java:177) ~[na:na]
	at java.base/sun.net.www.http.HttpClient.openServer(HttpClient.java:474) ~[na:na]
	at java.base/sun.net.www.http.HttpClient.openServer(HttpClient.java:569) ~[na:na]
	at java.base/sun.net.www.http.HttpClient.<init>(HttpClient.java:242) ~[na:na]
	at java.base/sun.net.www.http.HttpClient.New(HttpClient.java:341) ~[na:na]
	at java.base/sun.net.www.http.HttpClient.New(HttpClient.java:362) ~[na:na]
	at java.base/sun.net.www.protocol.http.HttpURLConnection.getNewHttpClient(HttpURLConnection.java:1242) ~[na:na]
	at java.base/sun.net.www.protocol.http.HttpURLConnection.plainConnect0(HttpURLConnection.java:1181) ~[na:na]
	at java.base/sun.net.www.protocol.http.HttpURLConnection.plainConnect(HttpURLConnection.java:1075) ~[na:na]
	at java.base/sun.net.www.protocol.http.HttpURLConnection.connect(HttpURLConnection.java:1009) ~[na:na]
	at org.springframework.http.client.SimpleBufferingClientHttpRequest.executeInternal(SimpleBufferingClientHttpRequest.java:76) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	at org.springframework.http.client.AbstractBufferingClientHttpRequest.executeInternal(AbstractBufferingClientHttpRequest.java:48) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	at org.springframework.http.client.AbstractClientHttpRequest.execute(AbstractClientHttpRequest.java:53) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	at org.springframework.web.client.RestTemplate.doExecute(RestTemplate.java:739) ~[spring-web-5.2.5.RELEASE.jar!/:5.2.5.RELEASE]
	... 21 common frames omitted

```


## create image and load it to the minikube registry

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

 