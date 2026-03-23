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

### 2.2 build a custom docker image

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
docker build -t hadoop-build-img-deb13 \
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

# connect to already running container
docker exec -it <container> bash
```

You can try to build hadoop with the below command.  

```shell
mvn -e -X clean package \
  -Pdist,native \
  -DskipTests \
  -Dmaven.javadoc.skip=true \
  -Dtar
```
- Pdist option: the target folder uses the distribution layout (bin, etc, sbin folders).
- Pnative option: Compiles C++ native code (highly recommended for performance).
- Dtar option: Creates a compressed .tar.gz file.
- DskipTests: Skips the unit tests (saves hours of build time).
- -Pyarn-ui: 	Builds the new YARN UI v2 (requires Node.js/Bower, included in Docker). not tested

> You can add `-e -X` for debugging

With this approach you will find out there are many options you need to pay attention when you build the docker image.
Hadoop provide a `start-build-env.sh` which allows you to build the image and create container more easily.

### 2.3 Use the native start-build-env.sh to build hadoop

Below is an example of `start-build-env.sh`

```bash
#!/usr/bin/env bash

set -e               # exit on error

cd "$(dirname "$0")" # connect to root

OS_PLATFORM="${1:-}"
[ "$#" -gt 0 ] && shift

DEFAULT_OS_PLATFORM="debian_13"

OS_PLATFORM_SUFFIX=""
DOCKER_PLATFORM_ARGS=()

if [[ -n ${OS_PLATFORM} ]]; then
  OS_PLATFORM_SUFFIX="_${OS_PLATFORM}"
else
  OS_PLATFORM_SUFFIX="_${DEFAULT_OS_PLATFORM}"
fi

DOCKER_DIR=dev-support/docker
DOCKER_FILE="${DOCKER_DIR}/Dockerfile${OS_PLATFORM_SUFFIX}"

CPU_ARCH=${CPU_ARCH:-$(uname -m)}
if [[ "$CPU_ARCH" == "x86_64" || "$CPU_ARCH" == "amd64" ]]; then
  DOCKER_PLATFORM_ARGS=("--platform" "linux/amd64")
elif [[ "$CPU_ARCH" == "aarch64" || "$CPU_ARCH" == "arm64" ]]; then
  DOCKER_FILE="${DOCKER_DIR}/Dockerfile${OS_PLATFORM_SUFFIX}_aarch64"
  DOCKER_PLATFORM_ARGS=("--platform" "linux/arm64")
fi

if [ ! -e "${DOCKER_FILE}" ] ; then
  echo "'${OS_PLATFORM}' environment not available yet for '${CPU_ARCH}'"
  exit 1
fi

docker build "${DOCKER_PLATFORM_ARGS[@]}" -t hadoop-build -f "${DOCKER_FILE}" "${DOCKER_DIR}"

USER_NAME=${SUDO_USER:=$USER}
USER_ID=$(id -u "${USER_NAME}")

if [ "$(uname -s)" = "Darwin" ]; then
  GROUP_ID=100
fi

if [ "$(uname -s)" = "Linux" ]; then
  GROUP_ID=$(id -g "${USER_NAME}")
  # man docker-run
  # When using SELinux, mounted directories may not be accessible
  # to the container. To work around this, with Docker prior to 1.7
  # one needs to run the "chcon -Rt svirt_sandbox_file_t" command on
  # the directories. With Docker 1.7 and later the z mount option
  # does this automatically.
  if command -v selinuxenabled >/dev/null && selinuxenabled; then
    DCKR_VER=$(docker -v|
    awk '$1 == "Docker" && $2 == "version" {split($3,ver,".");print ver[1]"."ver[2]}')
    DCKR_MAJ=${DCKR_VER%.*}
    DCKR_MIN=${DCKR_VER#*.}
    if [ "${DCKR_MAJ}" -eq 1 ] && [ "${DCKR_MIN}" -ge 7 ] ||
        [ "${DCKR_MAJ}" -gt 1 ]; then
      V_OPTS=:z
    else
      for d in "${PWD}" "${HOME}/.m2"; do
        ctx=$(stat --printf='%C' "$d"|cut -d':' -f3)
        if [ "$ctx" != svirt_sandbox_file_t ] && [ "$ctx" != container_file_t ]; then
          printf 'INFO: SELinux is enabled.\n'
          printf '\tMounted %s may not be accessible to the container.\n' "$d"
          printf 'INFO: If so, on the host, run the following command:\n'
          printf '\t# chcon -Rt svirt_sandbox_file_t %s\n' "$d"
        fi
      done
    fi
  fi
fi

# Set the home directory in the Docker container.
DOCKER_HOME_DIR=${DOCKER_HOME_DIR:-/home/${USER_NAME}}

docker build "${DOCKER_PLATFORM_ARGS[@]}" -t "hadoop-build${OS_PLATFORM_SUFFIX}-${USER_ID}" - <<UserSpecificDocker
FROM hadoop-build
RUN rm -f /var/log/faillog /var/log/lastlog
RUN userdel -r \$(getent passwd ${USER_ID} | cut -d: -f1) 2>/dev/null || :
RUN groupadd --non-unique -g ${GROUP_ID} ${USER_NAME}
RUN useradd -g ${GROUP_ID} -u ${USER_ID} -k /root -m ${USER_NAME} -d "${DOCKER_HOME_DIR}"
RUN echo "${USER_NAME} ALL=NOPASSWD: ALL" > "/etc/sudoers.d/hadoop-build-${USER_ID}"
ENV HOME="${DOCKER_HOME_DIR}"

UserSpecificDocker

# If this env variable is empty, docker will be started
# in non interactive mode
DOCKER_INTERACTIVE_RUN=${DOCKER_INTERACTIVE_RUN-"-i -t"}

# By mapping the .m2 directory you can do an mvn install from
# within the container and use the result on your normal
# system.  And this also is a significant speedup in subsequent
# builds because the dependencies are downloaded only once.
# shellcheck disable=SC2086
docker run "${DOCKER_PLATFORM_ARGS[@]}" --rm=true ${DOCKER_INTERACTIVE_RUN} \
  -v "${PWD}:${DOCKER_HOME_DIR}/hadoop${V_OPTS:-}" \
  -w "${DOCKER_HOME_DIR}/hadoop" \
  -v "${HOME}/.m2:${DOCKER_HOME_DIR}/.m2${V_OPTS:-}" \
  -v "${HOME}/.gnupg:${DOCKER_HOME_DIR}/.gnupg${V_OPTS:-}" \
  -u "${USER_ID}" \
  --name "hadoop-build${OS_PLATFORM_SUFFIX}" \
  "hadoop-build${OS_PLATFORM_SUFFIX}-${USER_ID}" "$@"
```
> pay attention on the parameter `DEFAULT_OS_PLATFORM`, the default value is ubuntu_24. As we use debian 13, so we change it to `debian_13`
> Because we know the `dockerfile` for debian_13 exist.

```shell
# run the start-build-env.sh
./start-build-env.sh

# expected output

# build the hadoop
mvn clean package \
  -Pdist,native \
  -DskipTests \
  -Dtar \
  -Dmaven.javadoc.skip=true 
```

> You are likely to fail the build at hadoop-common build step. The error message is cmake failed. 
> The real error message is located in `path/to/hadoop/hadoop-common-project/hadoop-common/target/native/CMakeFiles/CMakeConfigureLog.yaml`
> /opt/java/jdk11.0.30/include/jni.h:45:10: fatal error: jni_md.h: No such file or directory
> This bug is because cmake cannot find the platform-specific JNI header `jni_md.h`
> The below fix indicates the `jni_md.h` location is in `$JAVA_HOME/include/linux`

```shell
# build the hadoop with cmake include fix
mvn clean package \
  -Pdist,native \
  -DskipTests \
  -Dtar \
  -Dmaven.javadoc.skip=true \
  -Djava.home=$JAVA_HOME \
  -Djavacpp.include=$JAVA_HOME/include \
  -Djavacpp.platform.include=$JAVA_HOME/include/linux
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