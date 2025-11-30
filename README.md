
# Kubecluster GIT repo

## Bootstrapping flux

```
flux bootstrap git   --url=ssh://git@github.com:giovannitarter:22/kubecluster.git   --branch=main   --private-key-file=/root/.ssh/id_github   --path=clusters/first-cluster
```
