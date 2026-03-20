# Compile hadoop in debian 13

Hadoop provide a guide on how to build hadoop 
https://github.com/apache/hadoop/blob/trunk/BUILDING.txt

The releasing branch: https://github.com/apache/hadoop/tree/rel/release-3.3.6

> You can replace the 3.3.6 by any version of hadoop you want

## 1. Setup jdk

Your OS may come with pre-installed jdk. You need to remove them 

```shell
# list existing jdk 21
dpkg -l | grep -i openjdk-*

# remove all jdk
# --purge option also removes configuration files belonging to these packages
sudo apt purge --auto-remove 'openjdk-*'

# clean apt   
sudo apt autoremove
sudo apt autoclean
```

## 2. Use docker image to build hadoop

### 2.1 Download hadoop source

We need to clone the hadoop source first

```shell
git clone https://github.com/apache/hadoop.git
cd hadoop

git checkout rel/release-3.3.6
```

### 2.2 build the docker image

Hadoop already provides Dockerfiles under `path/to/hadoop/dev-support/docker`

You can check the content of this folder

```shell

cd /path/to/hadoop

ls dev-support/docker/

# expected output
Dockerfile_debian_12  Dockerfile_debian_13  Dockerfile_rockylinux_8  Dockerfile_ubuntu_24  Dockerfile_ubuntu_24_aarch64  Dockerfile_windows_10  hadoop_env_checks.sh  pkg-resolver  README.md  vcpkg

```
> This is the content of branch trunk. In the release branch, you can only find the default ubuntu_24 docker file
> 
> 
Choose your target OS dockerfile and build the image with the below command

```shell
# -t option tag the image with hadoop-build-img
# -f option specifies the docker image source to build the image
# the last argument `dev-support/docker` specifies the `build context directory` 
# that Docker can see and copy files from during build
docker build -t hadoop-build-img \
  -f dev-support/docker/Dockerfile_debian_13 \
  dev-support/docker
```

> You can't build a docker image based on the `Dockerfile_windows_10` on linux server. Because `Windows containers` 
> require the `Windows kernel` to execute any `RUN instruction` during build (even simple commands like `RUN dir` or `RUN powershell` ...).
> Docker build internally creates temporary containers to execute each layer → on a Linux host, it can only run Linux containers.
> 
> 
```shell
# mount the Hadoop source on the container /hadoop
# mount the maven cache on the container
# -w /hadoop option sets working dir to source root
# -u "1000" Run container processes as your host UID
# --name hadoop-build name for the container
# 
docker run --rm -it -v ~/hadoop:/home/hadoop -v ~/.m2:/home/.m2 -w /home/hadoop -u "1000" --name hadoop-build hadoop-build-img bash
```


```shell
mvn -e -X package -Pdist,native -DskipTests -Dmaven.javadoc.skip=true -Djava.home=$JAVA_HOME
```

## Install required packages

```shell
# update system first
sudo apt update
sudo apt upgrade

# install packages
sudo apt install -y \
  maven \
  cmake \
  pkg-config \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libsnappy-dev \
  libprotobuf-dev \
  protobuf-compiler \
  libsasl2-dev \
  libzstd-dev \
  git \
  curl
```

> You need install jdk 11, Hadoop 3.3.x builds best with java 11.
> 


## Fix OpenSSL 3 compatibility
## setup env var 

```shell
export MAVEN_OPTS="-Xmx4g"

export CFLAGS="-Wno-deprecated-declarations"
export CXXFLAGS="-Wno-deprecated-declarations"
```

##