# Harbor export/import images

Harbor do not support export and import images from local file system. But we can use docker client to pull(export) or push(import) images to a harbor server 

## Export an image from Harbor server

```shell
# login to harbor registry
docker login <harbor-url>

# pull the image from remote harbor repo to local docker
docker pull <harbor-url>/test/test-image

# for example, if the url is reg.casd.local, then do
docker login reg.casd.local
docker pull reg.casd.local/test/test-image

# check the image 
docker image list | grep -i "test-image"

# export the image to local file system as a tar file
docker save -o <img-name>.tar <repo-name>:<tag-name>

# for example to exmport an nginx with tag 1.24.0-bullseye
docker save -o nginx.tar nginx:1.24.0-bullseye

# copy the tar file to where you want
cp nginx.tar ./to/destination
```

> If your skip the tag name in the docker save step, you will never be able to get back this information again.

## Import an image into a Harbor server

```shell
# get the tar file of the target image
cp ./source/path/nginx.tar ./

# load the image into current docker repo
docker load -i nginx.tar

# check the image 
docker image list | grep -i "nginx"

# login to harbor registry
docker login <harbor-url>

# tag the image with harbor registry path
docker tag nginx:1.24.0-bullseye <harbor-url>/<project-name>/nginx:1.24.0-bullseye

# push the image from local docker repot to remote harbor repo
docker push <harbor-url>/<project-name>/nginx:1.24.0-bullseye
```

For more infor, read this page https://goharbor.io/docs/1.10/working-with-projects/working-with-images/pulling-pushing-images/