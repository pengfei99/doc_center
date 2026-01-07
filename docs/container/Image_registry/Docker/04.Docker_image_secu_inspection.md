# Docker image security inspection

To ensure the docker image security, we will follow the below step:
- If download from docker hub, check if it has the `official Badge`.
- If build locally, choose well the `base image`(will less vulnerability)
- Use docker image security scanner [tools](https://aquasecurity.github.io/trivy/v0.17.2/comparison/) to identify static vulnerabilities
- Use `docker bench`, `falco` to check run time vulnerabilities and anomalies 
- Regularly Update and Rebuild Images
- Issue documentation on docker images usage best practices 
- Regularly audit your Docker images, container configurations, and deployment environments for compliance with security policies.

## 1. Security check of the image provided by docker hub

### 1.1 The basic status of an image(docker hub)

Everyone can upload his local build docker image to docker hub. To distinguish with the homemade image, the official 
supported image has an `official bage`. You can view it :
 - from the docker hub website,  official images have a special "official" badge next to their name. This badge is 
          usually a blue ribbon icon or a label that says "Official Image". 
 - from docker client: You can use the below command

> For more information about DOI(docker official image), you can visit this page https://docs.docker.com/trusted-content/official-images/

```shell
docker search nginx

# output example
NAME                               DESCRIPTION                                     STARS     OFFICIAL   AUTOMATED
nginx                              Official build of Nginx.                        19946     [OK]       
bitnami/nginx                      Bitnami container image for NGINX               189                  [OK]

```

> Dockerhub has its own security controls on the official images. In general, we can trust the image with an `official bage`
> The `automated bage` means the image is built with an automated CI/CD pipeline. Bitnami is an organization which provide
> helm chart, it builds its own image for better suiting their helm chart. 
> 

#### Other sign of Official images

- **Image Namespace**: Official images typically reside in the root namespace, meaning they don’t have a username 
           prefix. For example, the official image for `Nginx is just nginx, not username/nginx`.
- **Description and Documentation**: Official images have thorough documentation and a well-maintained description page. 
             They often include detailed usage instructions, environment variables, and configuration options.


## 2 Check the docker image metadata

Docker provide tools to inspect the docker image metadata. Below is the command example

```shell
# general form
docker inspect <image_name_or_id>

# inspect the nginx image
docker inspect nginx

# the output is a json file, below is an output example
[
    {
        "Id": "sha256:6b1eed27cadeada9d1497f51c98c8e87d82753b7582ff5f94b4f9e6e1a6e2b7e",
        "RepoTags": [
            "nginx:latest"
        ],
        "RepoDigests": [
            "nginx@sha256:4c6909e8f15c97b39b1d9151c5c48c8d4b70c8be94e89f6b6e3e2b53d5c3b18f"
        ],
        "Parent": "",
        "Comment": "",
        "Created": "2021-03-01T23:05:29.495312831Z",
        "Container": "a8e6a8dcb9fbf7ab8d9b9e5e4f67f5a2d53e2b7e1a6b2b7b8a9e2c4d5e1b2e3d",
        "ContainerConfig": {
            "Hostname": "a8e6a8dcb9fb",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "ExposedPorts": {
                "80/tcp": {}
            },
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "nginx",
                "-g",
                "daemon off;"
            ],
            "Image": "sha256:b231e36b123b8c9c72b68d8e74f1c7a6b9b9f8c8d5b7e2b3e6b6f2b2e3d4a7f8",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": {}
        },


```


You need to pay attention on the below fields:
- **Id**: The unique identifier of the image.
- **RepoTags**: The tags associated with the image.
- **Created**: The timestamp when the image was created.
- **DockerVersion**: The version of Docker used to build the image.
- **Architecture**: The CPU architecture the image is built for.
- **Os**: The operating system the image is built for.
- **Size**: The size of the image.
- **VirtualSize**: The total size of the image, including its base layers.
- **Config**: Configuration details of the image, including environment variables, exposed ports, commands, etc.

## 3. Image security scanner tool

### 3.1 Trivy

You can visit their repo [github](https://github.com/aquasecurity/trivy).

Trivy is a comprehensive and versatile security scanner. It can be applied on the following targets:

- Container Image
- Filesystem
- Git Repository (remote)
- Virtual Machine Image
- Kubernetes
- AWS

what Trivy can detect on these target:

- OS packages and software dependencies in use (SBOM)
- Known vulnerabilities (CVEs)
- IaC issues and misconfigurations
- Sensitive information and secrets
- Software licenses


```shell
# show the security scan of image nginx 
trivy image --severity HIGH nginx

# output example
┌──────────────────┬────────────────┬──────────┬──────────────┬─────────────────────────┬────────────────────────┬──────────────────────────────────────────────────────────────┐
│     Library      │ Vulnerability  │ Severity │    Status    │    Installed Version    │     Fixed Version      │                            Title                             │
├──────────────────┼────────────────┼──────────┼──────────────┼─────────────────────────┼────────────────────────┼──────────────────────────────────────────────────────────────┤
│ bash             │ CVE-2022-3715  │ HIGH     │ affected     │ 5.1-2+deb11u1           │                        │ bash: a heap-buffer-overflow in valid_parameter_transform    │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2022-3715                    │
├──────────────────┼────────────────┤          ├──────────────┼─────────────────────────┼────────────────────────┼──────────────────────────────────────────────────────────────┤
│ bsdutils         │ CVE-2024-28085 │          │ fixed        │ 1:2.36.1-8+deb11u1      │ 2.36.1-8+deb11u2       │ util-linux: CVE-2024-28085: wall: escape sequence injection  │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2024-28085                   │
├──────────────────┼────────────────┤          ├──────────────┼─────────────────────────┼────────────────────────┼──────────────────────────────────────────────────────────────┤
│ curl             │ CVE-2022-42916 │          │ will_not_fix │ 7.74.0-1.3+deb11u3      │                        │ curl: HSTS bypass via IDN                                    │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2022-42916                   │
│                  ├────────────────┤          │              │                         ├────────────────────────┼──────────────────────────────────────────────────────────────┤
│                  │ CVE-2022-43551 │          │              │                         │                        │ curl: HSTS bypass via IDN                                    │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2022-43551                   │
│                  ├────────────────┤          ├──────────────┤                         ├────────────────────────┼──────────────────────────────────────────────────────────────┤
│                  │ CVE-2023-27533 │          │ fixed        │                         │ 7.74.0-1.3+deb11u8     │ curl: TELNET option IAC injection                            │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2023-27533                   │
│                  ├────────────────┤          │              │                         │                        ├──────────────────────────────────────────────────────────────┤
│                  │ CVE-2023-27534 │          │              │                         │                        │ curl: SFTP path ~ resolving discrepancy                      │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2023-27534                   │
│                  ├────────────────┤          ├──────────────┤                         ├────────────────────────┼──────────────────────────────────────────────────────────────┤
│                  │ CVE-2024-2398  │          │ affected     │                         │                        │ curl: HTTP/2 push headers memory-leak                        │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2024-2398                    │
├──────────────────┼────────────────┤          │              ├─────────────────────────┼────────────────────────┼──────────────────────────────────────────────────────────────┤
│ e2fsprogs        │ CVE-2022-1304  │          │              │ 1.46.2-2                │                        │ e2fsprogs: out-of-bounds read/write via crafted filesystem   │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2022-1304                    │
├──────────────────┼────────────────┤          ├──────────────┼─────────────────────────┼────────────────────────┼──────────────────────────────────────────────────────────────┤
│ libblkid1        │ CVE-2024-28085 │          │ fixed        │ 2.36.1-8+deb11u1        │ 2.36.1-8+deb11u2       │ util-linux: CVE-2024-28085: wall: escape sequence injection  │
│                  │                │          │              │                         │                        │ https://avd.aquasec.com/nvd/cve-2024-28085                   │


```


### CVE and CVSS

**CVE**: Common Vulnerabilities and Exposures (CVE)
**CVSS**: Common Vulnerability Scoring System

https://www.imperva.com/learn/application-security/cve-cvss-vulnerability/
https://fr.wikipedia.org/wiki/Common_Vulnerability_Scoring_System



