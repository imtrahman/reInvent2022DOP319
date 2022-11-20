#!/bin/bash
while getopts u:t: flag
do
    case "${flag}" in
        u) REPOSITORY_URI=${OPTARG};;
        t) TAG=${OPTARG};;
    esac
done
cat ./nginx-deploy.yaml | sed "s;image: .*;image: $(REPOSITORY_URI):$(TAG);" | kubectl apply -f -
