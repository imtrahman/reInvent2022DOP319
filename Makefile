#REGISTRY?=public.ecr.aws/h5s4y9s3/reinvent2022con319
REGISTRY?=public.ecr.aws/h5s4y9s3/reinvent2022dop319
TAG?=latest

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: albcon
albcon: ## Install AWS ALB Controller
	./installALBCon.sh

.PHONY: docker-build
docker-build:  ## Build Demo Application Container Image.
	docker build -t $(REGISTRY):$(TAG) .

.PHONY: docker-push
docker-push: docker-build ## ECR Login and Push Container Image to $(REGISTRY):$(TAG) .

	aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/h5s4y9s3
	docker push $(REGISTRY):$(TAG)

.PHONY: deploy
deploy: docker-build docker-push ## Deploy Sample application to EKS Cluster

	cat deploy/nginx-deploy.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: getingress
getingress: ## Get Deployed Ingress resource FQDN
	kubectl get ingress/reinvent2022dop319  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'


.PHONY: upgradeapp
upgradeapp: docker-build docker-push ## Deploy a new version of the Application on EKS
	
	cat deploy/upgrade-nginx.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: ingress-target

ingress-target: ## Change Ingress Resource Target type from InstanceId to IP Address
	
	cat deploy/deploy-nginx-ingress-target-ip.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: upgradetargetip

upgradetargetip: ## Upgrade APP with Ingress Resource Target type is IP Address
	
	cat deploy/upgrade-nginx-ingress-target-ip.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: deploy-fixed
deploy-fixed:  ## Deploy Sample application with best Practice to ensure Zero Downtime.

	cat deploy/nginx-fixed-deploy.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -
#	kubectl create -f deploy/nginx-fixed-deploy.yaml

.PHONY: zerodowntime 
zerodowntime: ## Upgrade Sample application with Zero Downtime.

	cat deploy/nginx-fixed-deploy.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: monitor
monitor: ## Monitor the deployed application by running `kubectl get pods`. 

	watch -n 1 kubectl get pods

.PHONY: locust
locust: ## Run a locust test to simulate load and test the website 
	~/.local/bin/locust -f /home/ec2-user/environment/locust/locustfile.py --host=http://`kubectl get ingress/reinvent2022dop319  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`

.PHONY: getalb
getalb: ## Show ALB controller running in the EKS cluster. 	

	kubectl get pods -n kube-system | grep -i aws-load-balancer-controller

.PHONY: cleanup
cleanup: ## Clean up everything
	
	kubectl delete -f deploy/nginx-deploy.yaml
	
#	/home/ec2-user/environment/data-api-app/imageCleanup.sh
