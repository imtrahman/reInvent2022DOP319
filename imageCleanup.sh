#!/bin/bash

for i in `kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='ExternalIP')].address}"`; do ssh -o StrictHostKeyChecking=no -i ~/.ssh/mytfs.pem ec2-user@$i sudo docker images ; done

for i in `kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='ExternalIP')].address}"`; do ssh -o StrictHostKeyChecking=no -i ~/.ssh/mytfs.pem ec2-user@$i sudo docker image prune -a -f ; done
