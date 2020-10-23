#!/bin/sh

#define parameters which are passed in.
BUILD_NUMBER=$1
# DOMAIN=$2

#define the template.
cat  << EOF
{
    "AWSEBDockerrunVersion": 2,
    "containerDefinitions": [
        {
            "name": "eb_frontend",
            "image": "cheeseman1213/issue-tracking-app-frontend:$BUILD_NUMBER",
            "essential": true,
            "memory": 1024,
            "portMappings": [
                {
                  "hostPort": 80,
                  "protocol": "tcp",
                  "containerPort": 80
                }
              ]
        },
        {
            "name": "eb_backend",
            "image": "cheeseman1213/issue-tracking-app-backend:$BUILD_NUMBER",
            "essential": true,
            "memory": 1024,
            "portMappings": [
                {
                  "hostPort": 8080,
                  "protocol": "tcp",
                  "containerPort": 8080
                }
              ]
        }
    ]
}
EOF