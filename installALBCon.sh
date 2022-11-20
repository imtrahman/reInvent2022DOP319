#!/bin/bash
EKSCLUSTER=$(eksctl get cluster | grep -i reinvent | awk '{print $1}')

#echo $EKSCLUSTER

	eksctl utils associate-iam-oidc-provider   --region ${AWS_REGION} --cluster ${EKSCLUSTER}   --approve

        aws iam create-policy  --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://ALB_iam_policy.json

	eksctl create iamserviceaccount --cluster ${EKSCLUSTER} --namespace kube-system --name aws-load-balancer-controller --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --approve

	kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

	kubectl get crd
#	
#	helm repo add eks https://aws.github.io/eks-charts
	
	helm install aws-load-balancer-controller  eks/aws-load-balancer-controller -n kube-system  --set clusterName="${EKSCLUSTER}" --set serviceAccount.create=false  --set serviceAccount.name=aws-load-balancer-controller

	kubectl -n kube-system rollout status deployment aws-load-balancer-controller
