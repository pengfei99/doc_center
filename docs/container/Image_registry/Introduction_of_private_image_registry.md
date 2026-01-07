# Private container image registry

As our platform can't have internet access, so we can't use public image registry.
As a result, we need to have private image registry.


## Which one is the best for us?

This [artical](https://bluelight.co/blog/how-to-choose-a-container-registry) compares many existing container image registry.

For now, we choose Harbor as our beta test solution

## Docker registry

## Harbor 

This [article](https://www.cyres.fr/blog/qu-est-ce-que-la-registry-harbor/) give a nice introduction about Harbor.


### Test instance

A test instance has been installed by using this [doc](./05.Harbor_standalone_installation.md). The host machine is 10.50.6.62 with url https://reg.casd.local

The login and password are in the keypass

## Appendix

### 1. What is OCI, OCI image/artifact/registry?

#### 1.1 OCI
The **OCI (Open Containers Initiative)** manages a few specifications and projects related to the `storage, distribution, and execution of container images`.


#### 1.2 OCI registry
The **OCI registry** is used for storing and distributing `container images`. It's possible to use OCI registry to store other types of data. There are a couple techniques for doing this, and one of them is commonly referred as **OCI Artifacts**

#### 1.3 OCI image VS Docker image

**Docker image and OCI image are not exactly the same thing**. Below example is an `Docker manifest`

```yaml
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
    "config": {
       "mediaType": "application/vnd.docker.container.image.v1+json",
       "size":233,
       "digest": "sha256:12335wq34sdfasdfasdf93432440sdfsdfsdfs0sdfsdfs0fsdfsfsdfs"
    },
    "layers": [
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip"
            "size":680,
            "digest": "sha256:12335wq34sdfasdfasdf93432440sdfsdfsdfs0sdfsdfs0fsdfsfsdfs"
        }
    ]
}
```

You can notice there are three `mediaType` configuration:
- manifest level: "application/vnd.docker.distribution.manifest.v2+json"
- config level: "application/vnd.docker.container.image.v1+json",
- layer level: "application/vnd.docker.image.rootfs.diff.tar.gzip"


You can notice they both have **docker** hardcoded in it. This is not acceptable for an OCI image manifest.

Below example is an `OCI manifest`

```yaml
{
    "schemaVersion": 2,
    "config": {
       "mediaType": "application/vnd.oci.image.config.v1+json",
       "size":233,
       "digest": "sha256:12335wq34sdfasdfasdf93432440sdfsdfsdfs0sdfsdfs0fsdfsfsdfs"
    },
    "layers": [
        {
            "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip"
            "size":680,
            "digest": "sha256:12335wq34sdfasdfasdf93432440sdfsdfsdfs0sdfsdfs0fsdfsfsdfs"
        }
    ]
}
```

You can notice that there are only two `mediaType` configuration:
- config level: "application/vnd.oci.image.config.v1+json"
- layer level: "application/vnd.oci.image.layer.v1.tar+gzip"

The manifest level mediaType config are not supported in the OCI manifest. Docker still has it because it wants to keep retro-compatibility with older version.

#### 1.4 OCI Artifact 

The OCI artifact is a OCI manifest. But it will not be used to build an image. Below example is an OCI artifact

```yaml
{
    "schemaVersion": 2,
    "config": {
       "mediaType": "application/vnd.mycustomartifact+json",
       "size":233,
       "digest": "sha256:12335wq34sdfasdfasdf93432440sdfsdfsdfs0sdfsdfs0fsdfsfsdfs"
    },
    "layers": [
        {
            "mediaType": "application/vnd.mycustomformat.tar+gzip"
            "size":680,
            "digest": "sha256:12335wq34sdfasdfasdf93432440sdfsdfsdfs0sdfsdfs0fsdfsfsdfs"
        }
    ]
}
```

You can notice the `two mediaType` (e.g. vnd.mycustomartifact+json; vnd.mycustomformat.tar+gzip) is customized to host custom file format. So this manifest will no longer produce an image.

As a result, we can differ an OCI artifact from a OCI image manifest :
- artifact sets a custom type in the `config.mediaType` field (unlike image manifest: vnd.oci.image.config.v1+json)
- artifact is storee in a registry
- artefact will not produce an image

