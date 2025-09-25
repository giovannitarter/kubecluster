



# Revoke and create a new pve token:
    - user: terraform@pve
    - token name: provider

```
pveum user token delete terraform@pve provider
pveum user token add terraform@pve provider --privsep=0

```

# destroy infra
```
tofu destroy -var-file="./secrets/secrets.tfvars"

```
# create infra
```
tofu init
tofu plan -out plan -var-file="./secrets/secrets.tfvars"
tofu apply plan
```
