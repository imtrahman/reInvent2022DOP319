#!/bin/bash
while getopts u:t: flag
do
    case "${flag}" in
        u) REPOSITORY_URI=${OPTARG};;
        t) TAG=${OPTARG};;
    esac
done
#export $REPOSITORY_URI
#export $TAG
cat ./nginx-deploy.yaml | sed "s;image: .*;image: $REPOSITORY_URI:$TAG;" | kubectl apply -f -
