build:
	GOOS=linux GOARCH=amd64 go build -o bootstrap lambda/main.go
	zip -9 lambda.zip bootstrap
	rm bootstrap

plan:
	terraform -chdir=infra plan -var-file=envs/prod.tfvars -out=.tfplan

apply:
	terraform -chdir=infra apply .tfplan

get-api-key: # API key is only for enforcing a global daily API quota and should not be considered sensitive
	terraform -chdir=infra output -raw api_key
