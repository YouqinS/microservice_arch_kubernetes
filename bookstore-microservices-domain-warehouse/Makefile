MICROSERVICE_NAME=micro-warehouse
IMAGE:=my-local/$(MICROSERVICE_NAME)
TAG:=v1
IMAGE_TAGGED:=$(IMAGE):$(TAG)

help:
	@echo 'Targets'
	@echo '   start'
	@echo '   image                 - create docker image and upload it to minikube container registry, parameter: TAG=v1 '
	@echo '   install               - build and install HELM chart to minikube'
	@echo '   uninstall             - NAME=<name-generated-by-helm>'
	@echo '   publish-image          - push docker image to DOCKER HUB repo, parameter: TAG=v1 '
	@echo '   configmap                     - create configmap to pass DB info to the application (set them in values.yaml -> configmap -> app) '




start:
	#cd .. && mvn clean install
	mvn spring-boot:run -Dspring-boot.run.profiles=mysql

jar:
	cd ../bookstore-microservices-library-infrastructure && mvn clean install
	cd ../bookstore-microservices-library-testing && mvn clean install
	mvn clean package

image: jar
    # https://github.com/kubernetes/minikube/issues/18021
	docker build -t $(IMAGE_TAGGED) .
	docker image save -o image.tar $(IMAGE_TAGGED)
	minikube image load image.tar
	rm -f image.tar


install:
	cd helm && helm package $(MICROSERVICE_NAME)
	cd helm && helm install  --generate-name  $(MICROSERVICE_NAME) --set image.pullPolicy=Never  --set image.repository=$(IMAGE) --set image.tag=v1 --set db.username=root  --set db.password=O4AhJYCYYh --set db.url="jdbc:mysql://my-release-mysql.default.svc.cluster.local:3306/warehouse?useUnicode=true&characterEncoding=utf-8"  --set db.host=my-release-mysql.default.svc.cluster.local   --set db.database=warehouse  --set db.jobDbCreation.image="bitnami/mysql:8.0.36-debian-12-r8"  --set db.jobDbCreation.pullPolicy=Never


uninstall:
	helm uninstall $(NAME)



publish-image:
	docker tag $(IMAGE_TAGGED)  xiaoouit/hu-csm-thesis:$(MICROSERVICE_NAME)-$(TAG)
	docker login -u xiaoouit  docker.io
	docker push xiaoouit/hu-csm-thesis:$(MICROSERVICE_NAME)-$(TAG)
	docker logout
	docker pull xiaoouit/hu-csm-thesis:$(MICROSERVICE_NAME)-$(TAG)


curl:
	kubectl run mycurlpod --image=curlimages/curl -i --tty -- sh

configmap:
	cd helm/mono-bs/template && kubectl create configmap myConfigmap --from-literal=spring.datasource.url="myurl"  --from-literal=spring.datasource.username="myusername"  --from-literal=spring.datasource.password="mypw" --dry-run=client -o yaml > configmap.yaml

drop-schema:
	mysql -h "my-release-mysql.default.svc.cluster.local " -u"root" -p"O4AhJYCYYh" -e"DROP DATABASE account ;"
