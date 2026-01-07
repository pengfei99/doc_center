# Scan vulnerability of an container image

Trivy is an tool for detecting vulnerability of a target. The target can be:
- Container Image
- Filesystem
- Git Repository (remote)
- Virtual Machine Image
- Kubernetes
- AWS


It can detect:

- OS packages and software dependencies in use (SBOM)
- Known vulnerabilities (CVEs)
- IaC issues and misconfigurations
- Sensitive information and secrets
- Software licenses

For more information, you can visit their [github](https://github.com/aquasecurity/trivy) 

## Install Trivy

For debian/ubuntu

Run the following script

```shell
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

## Use trivy to analyse an Image

By default, trivy use docker hub as the image registry

```shell
# print all vulnerability
trivy image python:3.4-alpine

# filter result by their severity
trivy image --severity HIGH python:3.4-alpine
```

## Use trivy to analyse various sources

If you have sources such as `Dockerfile`, `terraform`, `k8s deployment`

```shell
# analyse source file under a folder
trivy fs --security-checks vuln,secret,config <parent-folder>

# you can use the sample docker file in the resources/harbor/Trivy
trivy fs --security-checks vuln,secret,config resources/harbor/Trivy/python_ds/
```

## Integrate Trivy into Harbor