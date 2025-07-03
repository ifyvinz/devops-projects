# AWS VPC Infrastructure with Terraform

This Terraform setup provisions:

- VPC in `eu-north-1`
- 2 Public and 2 Private subnets
- Internet Gateway and NAT Gateway
- Bastion Host in public subnet
- Security Groups and Route Tables

## Bastion Host

Access private instances by SSH-ing through the bastion host:
```bash
ssh -i xx-key.pem ec2-user@<bastion_ip>
