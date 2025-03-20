```
Error: creating API Gateway Domain Name (yourdomain.com): Certificate ___ in account ___ not yet issued

```

1. Go to ACM and find the created certificate.
2. Click into it and find the validation record (CNAME name and value).
3. Go to your domain registrar and create a CNAME record with the name and value found in the previous step.
4. Wait for the certificate to be issued (it should show status "Issued" in ACM).
5. Run `make plan` and `make apply` again.

### Hooking up the domain to the API Gateway:

You should create the A alias record for your custom domain pointing to the API Gateway's target domain name. Based on your configuration:
Create an A alias record with:

Record Name: yourdomain.com  
Record Type: A (Alias)  
Alias Target: {target_domain_name}  
Alias Hosted Zone ID: {hosted_zone_id}
