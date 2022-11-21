# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

FROM public.ecr.aws/nginx/nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf 
WORKDIR /usr/share/nginx/html/
COPY css css/
COPY images images/
COPY index.html /usr/share/nginx/html
WORKDIR /
ENTRYPOINT ["nginx", "-g", "daemon off;"]
