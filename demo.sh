#!/bin/bash

#
# variables
#
GITHUB_USERNAME=imtrahman
AWS_REGION=us-east-1

TAG="$(date +%Y%m%d%H%M%S)$(git rev-parse HEAD | head -c 8)"
export SERVICE_NAME=sample-lambda-function-template # This is for terraform provisioning 

PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"

export AWS_PROFILE AWS_REGION PROJECT_NAME PROJECT_DIR GITHUB_USERNAME


log()   { echo -e "\e[30;47m ${1^^} \e[0m ${@:2}"; }        # $1 uppercase background white
info()  { echo -e "\e[48;5;28m ${1^^} \e[0m ${@:2}"; }      # $1 uppercase background green
warn()  { echo -e "\e[48;5;202m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background orange
error() { echo -e "\e[48;5;196m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background red

# https://unix.stackexchange.com/a/22867
export -f log info warn error

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./demo.sh dev'
}


# local development
protonrole() {

    cd "$PROJECT_DIR"
cat <<"EOF" > ./proton-service-assume-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "proton.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    aws iam create-role --role-name ProtonServiceRole --assume-role-policy-document file://./proton-service-assume-policy.json 
    aws iam attach-role-policy --role-name ProtonServiceRole --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    aws proton update-account-settings --region $AWS_REGION --pipeline-service-role-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ProtonServiceRole"
}


codestarconnection(){

	aws codestar-connections create-connection --provider-type GitHub --connection-name MyConnection

}


reposync(){

	echo "export GITHUB_USERNAME=${GITHUB_USERNAME}" | tee -a ~/.bash_profile
	CODESTAR_CONNECTION_ARN=$(aws codestar-connections list-connections --provider-type GitHub --region ${AWS_REGION} | jq -r '.Connections[] | select( .ConnectionName=="MyConnection") | .ConnectionArn')
	aws proton create-repository --region ${AWS_REGION} --connection-arn $CODESTAR_CONNECTION_ARN --name "${GITHUB_USERNAME}/aws-proton-workshop-code" --provider "GITHUB"

}


clonerepo() {
	git clone https://github.com/${GITHUB_USERNAME}/aws-proton-workshop-code.git
	cd "$PROJECT_DIR/aws-proton-workshop-code"

}


regenvtemplate(){

	aws proton create-environment-template --region ${AWS_REGION}  --name "multi-svc-env" --display-name "Multi Service Environment" --description "Environment with VPC and public subnets"

}


envtemplatesync(){

	REPOSITORY_ARN=$(aws proton list-repositories | jq -r '.repositories[] | select( .name | endswith("aws-proton-workshop-code")) | .arn')
	REPOSITORY_NAME=$(echo $REPOSITORY_ARN | cut -d':' -f7)
	REPOSITORY_PROVIDER=$(echo $REPOSITORY_ARN | cut -d':' -f6 | tr a-z A-Z)
	aws proton create-template-sync-config --region ${AWS_REGION} --repository-name $REPOSITORY_NAME --repository-provider ${REPOSITORY_PROVIDER#"REPOSITORY/"} --branch main --subdirectory "aws-managed/multi-svc-env" --template-name "multi-svc-env" --template-type "ENVIRONMENT"

}

publishenvtemplate(){

	aws proton update-environment-template-version --region ${AWS_REGION} --template-name "multi-svc-env" --major-version "1" --minor-version "0" --status "PUBLISHED"

}
emptycommit(){
	cd "$PROJECT_DIR/aws-proton-workshop-code"
	git commit --allow-empty -m "Trigger Sync" && git push origin main
}


createenv(){
	SPEC=$(cat $PROJECT_DIR/envspec.yaml)
	echo $SPEC
	aws proton create-environment --region ${AWS_REGION} --name "multi-svc-beta" --template-name "multi-svc-env" --template-major-version 1 --proton-service-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/ProtonServiceRole --spec "$SPEC"

}

regsvctemplate(){
	aws proton create-service-template --region ${AWS_REGION} --name "lb-fargate-service" --display-name "LoadbalancedFargateService" --description "Fargate Service with an Application Load Balancer"

}


svctemplatesync(){
	REPOSITORY_ARN=$(aws proton list-repositories | jq -r '.repositories[] | select( .name | endswith("aws-proton-workshop-code")) | .arn')
      	REPOSITORY_NAME=$(echo $REPOSITORY_ARN | cut -d':' -f7)
	REPOSITORY_PROVIDER=$(echo $REPOSITORY_ARN | cut -d':' -f6 | tr a-z A-Z)
	aws proton create-template-sync-config --region ${AWS_REGION}  --repository-name $REPOSITORY_NAME --repository-provider ${REPOSITORY_PROVIDER#"REPOSITORY/"}  --branch main  --subdirectory "aws-managed/lb-fargate-service" --template-name "lb-fargate-service"  --template-type "SERVICE"
}

publishsvctemplate(){

	aws proton update-service-template-version --region ${AWS_REGION}  --template-name "lb-fargate-service" --major-version "1" --minor-version "0" --status "PUBLISHED"
}

createsvc(){
	CODESTAR_CONNECTION_ARN=$(aws codestar-connections list-connections --provider-type GitHub --region ${AWS_REGION} | jq -r '.Connections[] | select( .ConnectionName=="MyConnection") | .ConnectionArn')
	FRONTENDSPEC=$(cat $PROJECT_DIR/frontendsvcspec.yaml)
	CRYSTALSPEC=$(cat $PROJECT_DIR/crystalsvcspec.yaml)
	NODEJSSPEC=$(cat $PROJECT_DIR/nodejssvcspec.yaml)
#	echo $FRONTENDSPEC
	aws proton create-service  --region ${AWS_REGION}  --name "frontend" --template-major-version 1  --template-name lb-fargate-service --spec "$FRONTENDSPEC" --repository-connection-arn $CODESTAR_CONNECTION_ARN --repository-id $GITHUB_USERNAME/ecsdemo-frontend --branch-name main

#	echo $CRYSTALSPEC
	aws proton create-service  --region ${AWS_REGION}  --name "crystal" --template-major-version 1  --template-name lb-fargate-service --spec "$CRYSTALSPEC" --repository-connection-arn $CODESTAR_CONNECTION_ARN --repository-id $GITHUB_USERNAME/ecsdemo-crystal --branch-name main
	
#	echo $NODEJSSPEC
	aws proton create-service  --region ${AWS_REGION}  --name "nodejs" --template-major-version 1  --template-name lb-fargate-service --spec "$NODEJSSPEC" --repository-connection-arn $CODESTAR_CONNECTION_ARN --repository-id $GITHUB_USERNAME/ecsdemo-nodejs --branch-name main

}

svcurl(){
	aws proton list-service-instance-outputs --service-instance-name frontend-beta --service-name frontend | jq -r '.outputs[]'

}


######terraform demo steps


gitactionrole(){
	mkdir $PROJECT_DIR/env-workshop
	wget -O $PROJECT_DIR/env-workshop/GitHubConfiguration.yaml "https://raw.githubusercontent.com/${GITHUB_USERNAME}/aws-proton-workshop-code/main/GitHubConfiguration.yaml"
	aws cloudformation create-stack --stack-name aws-proton-terraform-role-stack --template-body file://$PROJECT_DIR/env-workshop/GitHubConfiguration.yaml --parameters ParameterKey=FullRepoName,ParameterValue=${GITHUB_USERNAME}/aws-proton-workshop-code --capabilities CAPABILITY_NAMED_IAM
}

displaygitroleandS3(){
	GITROLEARN=$(aws cloudformation describe-stacks --stack-name aws-proton-terraform-role-stack | jq '.Stacks[].Outputs[0].OutputValue')
	S3BUCKETNAME=$(aws cloudformation describe-stacks --stack-name aws-proton-terraform-role-stack | jq '.Stacks[].Outputs[1].OutputValue')
	echo $GITROLEARN
	echo $S3BUCKETNAME
	echo "MESSAGE: Navigate to "env_config.json" in aws-proton-workshop-code repo and update it with above role ARN and S3" 
}


teraregenvtemplate(){
	export ENVIRONMENT_NAME=sample-vpc-environment-template
	aws proton create-environment-template --region ${AWS_REGION} --name ${ENVIRONMENT_NAME} --display-name "Lambda TF Environment" --description "Environment with VPC and public subnets"	
}

teraenvtemplatesync(){
	export ENVIRONMENT_NAME=sample-vpc-environment-template
	aws proton create-template-sync-config --template-name "${ENVIRONMENT_NAME}" --template-type "ENVIRONMENT" --repository-name "${GITHUB_USERNAME}/aws-proton-workshop-code" --repository-provider "GITHUB" --branch "main" --subdirectory "/lambda-vpc/sample-vpc-environment-template/"
}


terapublishenvtemplate(){
	aws proton update-environment-template-version --region ${AWS_REGION} --template-name "${ENVIRONMENT_NAME}"   --major-version "1" --minor-version "0" --status "PUBLISHED"
}

teracreateenv(){
	SPEC=$(cat $PROJECT_DIR/teraenvspec.yaml)
	echo $SPEC
	aws proton create-environment --region ${AWS_REGION} --name "${ENVIRONMENT_NAME}" --template-name "${ENVIRONMENT_NAME}" --template-major-version 1 --provisioning-repository="branch=main,name=$GITHUB_USERNAME/aws-proton-workshop-code,provider=GITHUB" --spec "$SPEC"

}


teraregsvctemplate(){
	aws proton create-service-template --region ${AWS_REGION} --name ${SERVICE_NAME} --display-name "Lambda TF Service" --description "Service with lambda function" --pipeline-provisioning "CUSTOMER_MANAGED"
}

terasvctemplatesync(){
	cd $PROJECT_DIR/aws-proton-workshop-code
	git pull origin main
	echo "sample-vpc-environment-template:1" > lambda-vpc/sample-lambda-function-template/v1/.compatible-envs
	git add lambda-vpc/sample-lambda-function-template/v1/.compatible-envs
	git commit -m "adds .compatible-envs to initiate template version"
	git push origin main
	aws proton create-template-sync-config --template-name "${SERVICE_NAME}" --template-type "SERVICE" --repository-name "${GITHUB_USERNAME}/aws-proton-workshop-code" --repository-provider "GITHUB" --branch "main" --subdirectory "/lambda-vpc/sample-lambda-function-template/"
}

terapublishsvctemplate(){
	aws proton update-service-template-version --region ${AWS_REGION} --template-name "${SERVICE_NAME}" --major-version "1" --minor-version "0" --status "PUBLISHED"
}

teracreatesvc(){
#	aws s3 mb s3://"proton-lambda-function-svc-${AWS_ACCOUNT_ID}-${AWS_REGION}-${TIMESTAMP}" 
#	wget -O lambda_function.py https://raw.githubusercontent.com/${GITHUB_USERNAME}/aws-proton-workshop-code/main/lambda-vpc/sample-lambda-function-template/v1/lambda_function.py
#	zip lambda_service_function.zip lambda_function.py
#	aws s3 cp lambda_service_function.zip s3://"proton-lambda-function-svc-${AWS_ACCOUNT_ID}-${AWS_REGION}-${TIMESTAMP}/"
	
	SPEC=$(cat $PROJECT_DIR/lambdasvcspec.yaml)
	aws proton create-service --name ${SERVICE_NAME} --template-name ${SERVICE_NAME} --template-major-version "1" --spec "$SPEC"
	
}

#####Link Account role for mult-account deployment

multiaccountrole(){
	aws cloudformation deploy --template-file $PROJECT_DIR/proton-account-connection-roles.yaml --stack-name AWSProtonWorkshop-AccountConnectionRoles  --parameter-overrides "EnvironmentAccountId=${SECONDARY_ENV_ACCOUNT_ID}" --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM"

}


switchroleendpoint(){
	aws cloudformation describe-stacks --stack-name AWSProtonWorkshop-AccountConnectionRoles |  jq -r '.Stacks[0].Outputs[0].OutputValue'

}

FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info execute $1; eval $1; } || usage;
exit 0
