#!/bin/sh

aws s3 cp --acl public-read demo-bucket-content/ "s3://${DEMO_DEPLOY_BUCKET}" --recursive
