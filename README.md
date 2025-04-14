# rotate-secrets-demo

Rotate Secrets with external-secrets-operator demo

This repository contains code for KCD Budapest presentation for rotating secrets using external-secrets-operator.

To run the entire demo, please execute `./run.sh`.

- got to use one of the cooler generators like vault or an AWS one
    - note, binary download for vault here: https://developer.hashicorp.com/vault/install


https://releases.hashicorp.com/vault/1.19.1/vault_1.19.1_linux_amd64.zip
https://releases.hashicorp.com/vault/1.19.1/vault_1.19.1_darwin_amd64.zip

```
curl -L https://releases.hashicorp.com/vault/1.19.1/vault_1.19.1_darwin_amd64.zip -o vault.zip && unzip vault.zip -d bin && rm vault.zip
```

https://marpit.marp.app/directives