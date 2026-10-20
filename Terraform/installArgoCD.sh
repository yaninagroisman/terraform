V=v3.5.5
cd /tmp
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$V/argocd-linux-amd64
curl -sSL -o cli_checksums.txt https://github.com/argoproj/argo-cd/releases/download/$V/cli_checksums.txt

# проверка целостности: должно вывести "argocd-linux-amd64: OK"
grep ' argocd-linux-amd64$' cli_checksums.txt | sed 's/argocd-linux-amd64/argocd/' | sha256sum -c -

sudo install -m 555 argocd /usr/local/bin/argocd
rm argocd cli_checksums.txt
