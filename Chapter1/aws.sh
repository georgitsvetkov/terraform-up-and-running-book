#!/bin/bash

doormat login -f
eval $(doormat aws export --role arn:aws:iam::938620692197:role/support_emea1_dev-developer)
aws configure set region eu-west-1
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set aws_session_token $AWS_SESSION_TOKEN
aws configure set output json
