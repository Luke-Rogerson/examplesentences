build:
	GOOS=linux GOARCH=amd64 go build -o bootstrap lambda/main.go
	zip -9 lambda.zip bootstrap
	rm bootstrap

plan:
	terraform -chdir=infra plan -var-file=envs/prod.tfvars -out=.tfplan -var "telegram_bot_token=$(TELEGRAM_BOT_TOKEN)" -var "telegram_chat_id=$(TELEGRAM_CHAT_ID)"

apply:
	terraform -chdir=infra apply .tfplan

get-api-key: # API key is only for enforcing a global daily API quota and should not be considered sensitive
	terraform -chdir=infra output -raw api_key

start-frontend-dev:
	cd frontend && pnpm dev