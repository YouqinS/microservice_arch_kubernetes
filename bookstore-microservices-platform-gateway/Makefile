MICROSERVICE_NAME=micro-gateway
IMAGE:=my-local/$(MICROSERVICE_NAME)
TAG:=v1
IMAGE_TAGGED:=$(IMAGE):$(TAG)

help:
	@echo 'Targets'
	@echo '   image                 - create docker image and upload it to minikube container registry, parameter: TAG=v1 '
	@echo '   install               - build and install HELM chart to minikube'
	@echo '   uninstall             - NAME=<name-generated-by-helm>'
	@echo '   publish-image          - push docker image to DOCKER HUB repo, parameter: TAG=v1 '
	@echo '   configmap                     - create configmap to pass DB info to the application (set them in values.yaml -> configmap -> app) '




jar:
	mvn clean package

image: jar
    # https://github.com/kubernetes/minikube/issues/18021
	docker build -t $(IMAGE_TAGGED) .
	docker image save -o image.tar $(IMAGE_TAGGED)
	minikube image load image.tar
	rm -f image.tar


install:
	cd helm && helm package $(MICROSERVICE_NAME)
	cd helm && helm install  --generate-name  $(MICROSERVICE_NAME) --set image.pullPolicy=Never  --set image.repository=$(IMAGE) --set image.tag=v1   --set db.jobDbCreation.pullPolicy=Never


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
