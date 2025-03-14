1. auth token: export LOCALSTACK_AUTH_TOKEN="ls-WAGeNaPO-WITI-FiGA-2373-1251paFIa49a"
2. aws acces keys
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ENDPOINT_URL=http://localhost:4566


- Terraform output
terraform output eks_cluster_name
terraform output eks_cluster_endpoint


- Creating eks cluster [done]


# For pushing docker image to ecr repo
docker tag flask-app:latest 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/nginx-repo:flask-app


# Post deploying
Deploying -> service -> ingress
curl http://localhost:8081/get