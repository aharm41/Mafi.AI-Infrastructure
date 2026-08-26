# Mafiai Terraform

This is a barebones AWS scaffold containing:

- separate Fargate ECS clusters and services for menu and game;
- CPU target-tracking service autoscaling;
- a private S3 bucket and CloudFront distribution for `content-r`;
- a Route 53 hosted zone and apex alias to CloudFront.

Create a public hosted zone for the domain in Route 53 first, set its four name
servers at your registrar, and put that hosted zone's ID in
`route53_zone_id`. Terraform treats the zone as external infrastructure and
manages only the records within it.

Copy `terraform.tfvars.example` to `terraform.tfvars`, replace the placeholders,
then run:

```sh
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Adding some stuff here

## Deploying the frontend

Terraform creates a private S3 bucket and CloudFront distribution; it does not
upload application files. `content-r` is a Vite React application, so its
production build is written to `content-r/dist/`.

After the Terraform apply has created the bucket and distribution, build and
deploy the frontend from the repository root:

```sh
cd content-r
npm install
npm run build

BUCKET=$(terraform -chdir=../inf output -raw frontend_bucket_name)
aws s3 sync dist/ "s3://$BUCKET" --delete

DISTRIBUTION_ID=$(terraform -chdir=../inf output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*"
```

`--delete` removes objects from the bucket that are no longer part of the
current build. The invalidation makes CloudFront fetch the new files instead of
serving a previously cached frontend. The AWS CLI identity running these
commands needs permission to list, upload, and delete bucket objects, plus
permission to create CloudFront invalidations.

The bucket remains private: the bucket policy permits CloudFront to read it;
the deployment identity is the only other principal that needs write access.

`content-r` uses browser-based React routing. Add both of the following
`custom_error_response` blocks to the CloudFront distribution so direct visits
to client-side routes load `index.html`:

```hcl
custom_error_response {
  error_code         = 403
  response_code      = 200
  response_page_path = "/index.html"
}

custom_error_response {
  error_code         = 404
  response_code      = 200
  response_page_path = "/index.html"
}
```

Delegate the Route 53 nameservers at your domain registrar before applying this
configuration. Terraform creates the ACM certificate-validation records and
CloudFront alias records in that existing zone.

This scaffold assumes an existing VPC, private subnets, security group, ECR
images, and NAT/VPC endpoints for Fargate image/log access. It does not yet
create load balancers, Redis/Valkey, secrets, or ECS task environment
variables.
