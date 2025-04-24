#!/bin/bash

latest=$(curl -L https://api.github.com/repos/external-secrets-inc/reloader/releases/latest | jq -r .tag_name)

curl -L https://github.com/external-secrets-inc/reloader/releases/download/"${latest}"/bundle.yaml | kubectl apply -f -

# kubectl create deployment my-dep --image=busybox -- sleep 999999

echo "kubectl patch secret test -p '{"data":{"token":"bmV3LXRva2VuLXZhbHVl"}}'"