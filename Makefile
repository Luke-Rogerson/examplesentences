build:
	GOOS=linux GOARCH=amd64 go build -o bootstrap lambda/main.go
	zip -9 lambda.zip bootstrap
	rm bootstrap

plan:
	terraform -chdir=infra plan -out=.tfplan

apply:
	terraform -chdir=infra apply .tfplan

