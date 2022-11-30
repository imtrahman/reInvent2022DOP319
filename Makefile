#### Variable Section

REGISTRY?=public.ecr.aws/h5s4y9s3/reinvent2022dop319
REVISION?=1
OLDTAG?=20221129145806
#TAG := $(shell echo `date +%Y%m%d%H%M%S``git rev-parse HEAD | head -c 8`)
TAG := $(shell echo `date +%Y%m%d%H%M%S`)
LOCUSTIP := $(shell aws ec2 describe-instances --filters Name=private-dns-name,Values=`hostname -f` --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

####  Help Section

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)



.PHONY: docker-build
docker-build:  ## Build Demo Application Container Image.
	docker build -t $(REGISTRY):$(TAG) .


.PHONY: docker-push
docker-push: docker-build ## ECR Login and Push Container Image to $(REGISTRY):$(TAG) .

	@aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/h5s4y9s3

	docker push $(REGISTRY):$(TAG)

.PHONY: deploy
deploy: docker-build docker-push ## Deploy Sample application to EKS Cluster

	@cat deploy/nginx-deploy.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -
	@echo \n
	@kubectl get deploy/reinvent2022dop319 -o jsonpath="{..image}"

.PHONY: rollout
rollout: ## Check the Deployment revision number
	@kubectl rollout history deployment/reinvent2022dop319

.PHONY: rollback
rollback: ## Rollback the deployment to previous version
	@kubectl rollout undo deployment/reinvent2022dop319 --to-revision=$(REVISION)


.PHONY: getingress
getingress: ## Get Deployed Ingress resource FQDN
	@kubectl get ingress/reinvent2022dop319  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo \

.PHONY: updateingress

updateingress: ## Change Ingress Resource Target type from InstanceId to IP Address
	
#	@echo TAG IS $(TAG)	
	@cat deploy/deploy-nginx-ingress-target-ip.yaml | sed "s;image: .*;image: $(REGISTRY):$(OLDTAG);" | kubectl apply -f -

.PHONY: upgradetargetip
upgradetargetip: docker-build docker-push ## Upgrade APP with Ingress Resource Target type is IP Address
	
	@echo TAG IS $(TAG)	
	@cat deploy/upgrade-nginx-ingress-target-ip.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: imagetag
imagetag: ## list Puhsed image tags
	@aws ecr-public describe-images --region us-east-1 --output json --repository-name reinvent2022dop319 --query 'sort_by(imageDetails,& imagePushedAt)[].imageTags' | jq . --raw-output

.PHONY: deployzerodowntime
deployzerodowntime:  ## Deploy Sample application with best Practice to ensure Zero Downtime.

	@echo TAG IS $(OLDTAG)	
	@cat deploy/nginx-fixed-deploy.yaml | sed "s;image: .*;image: $(REGISTRY):$(OLDTAG);" | kubectl apply -f -
#	kubectl apply -f deploy/nginx-fixed-deploy.yaml 

.PHONY: upgradezerodowntime 
upgradezerodowntime: docker-build docker-push ## Upgrade Sample application with Zero Downtime.

	@echo TAG IS $(TAG)	
	@cat deploy/nginx-fixed-deploy.yaml | sed "s;image: .*;image: $(REGISTRY):$(TAG);" | kubectl apply -f -

.PHONY: monitor
monitor: ## Monitor the deployed application by running `kubectl get pods`. 

	@watch -n 1 kubectl get pods

.PHONY: locust
locust: ## Run a locust test to simulate load and test the website 
	@echo Locust using http://$(LOCUSTIP):8089
	@~/.local/bin/locust -f /home/ec2-user/environment/locust/locustfile.py --host=http://`kubectl get ingress/reinvent2022dop319  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'` > /dev/null 2>&1

.PHONY: ep
ep: ## Monitor the deployed application by running `kubectl get endpoints`. 

	@watch -n 1 kubectl get ep 

.PHONY: getalb
getalb: ## Show ALB controller running in the EKS cluster. 	

	kubectl get pods -n kube-system | grep -i aws-load-balancer-controller

.PHONY: cleanup
cleanup: ## Clean up everything
	
	kubectl delete -f deploy/nginx-deploy.yaml
	
#	/home/ec2-user/environment/data-api-app/imageCleanup.sh
