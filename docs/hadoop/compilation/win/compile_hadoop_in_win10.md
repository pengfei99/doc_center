# Compile hadoop in Windows 10

I found this doc is very clear and has many details

https://kontext.tech/project/hadoop/article/compile-and-build-hadoop-321-on-windows-10-guide

## 1. Hadoop official docs for building hadoop on Windows 10
Hadoop provides an [official docs](https://github.com/apache/hadoop/blob/trunk/BUILDING.txt) on how to build hadoop for different OS.

The below content is an extraction of 23/03/2026

## 2. Requirements:

The below rows shows the build environment requirements:
- Windows 10 
- JDK 17 
- Maven 3.9.11 or later (maven.apache.org, optional, a compatible version is automatically downloaded if using mvnw.cmd)
- Boost 1.86.0 (boost.org)
- Protocol Buffers 3.25.5 (https://github.com/protocolbuffers/protobuf/tags)
- CMake 3.19 or newer (cmake.org)
- Visual Studio 2019 (visualstudio.com)
- Windows SDK 8.1 (optional, if building CPU rate control for the container executor. Get this from
                   http://msdn.microsoft.com/en-us/windows/bg162891.aspx)
- Zlib (zlib.net, if building native code bindings for zlib)
- Git (preferably, get this from https://git-scm.com/download/win since the package also contains
       Unix command-line tools that are needed during packaging). 
- Python (python.org, for generation of docs using 'mvn site')
- Internet connection for first build (to fetch all Maven and Hadoop dependencies)


## 3. Building guidelines

Hadoop repository provides the Dockerfile for building Hadoop on Windows 10, located at
dev-support/docker/Dockerfile_windows_10. It is highly recommended to use this and create the
Docker image for building Hadoop on Windows 10, since you don't have to install anything else
other than Docker and no additional steps are required in terms of aligning the environment with
the necessary paths etc.

However, if you still prefer taking the route of not using Docker, this Dockerfile_windows_10 will
still be immensely useful as a raw guide for all the steps involved in creating the environment
needed to build Hadoop on Windows 10.

## 4. Building Docker image

We first need to clone the hadoop repository, then build the Docker image for building Hadoop on Windows 10. Run this command from
the root of the Hadoop repository.

```powershell
# create a folder for hosting hadoop project source
mkdir -p /c/Users/<uid>/Documents/git/hadoop
cd /c/Users/<uid>/Documents/git/hadoop

# clone the hadoop repo
git clone https://github.com/apache/hadoop.git

# path for git bash shell
# you need to have admin rights on the git bash shell
# -t option means tag your image with name hadoop-windows-builder
# -f option indicates where is the docker file
# the last argument specifies the working directory during docker build, if you have relative path for
# copying source into docker image in your docker file. You can't leave it empty.
# 
docker build -t hadoop-windows-builder -f ./dev-support/docker/Dockerfile_windows_10 ./dev-support/docker/

# test the container with the image that we just built.
docker run --rm -it hadoop-windows-builder
```
> here, we use the git bash shell, so the path is for bash shell only, if you use powershell, you need to modify
> the path. You can use this page to install git bash on windows https://git-scm.com/install/windows
> 
> You can now clone the Hadoop repo inside this container and proceed with the build.

### 4.1 The official docker file 

hadoop does provide a docker file for building hadoop in windows. You can find the origin [DockerFile](https://github.com/apache/hadoop/blob/trunk/dev-support/docker/Dockerfile_windows_10).

```shell
FROM mcr.microsoft.com/windows:ltsc2019

# Need to disable the progress bar for speeding up the downloads.
# hadolint ignore=SC2086
RUN powershell $Global:ProgressPreference = 'SilentlyContinue'

# Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

# Install Visual Studio 2019 Build Tools.
RUN curl -SL --output vs_buildtools.exe https://aka.ms/vs/16/release/vs_buildtools.exe \
    && (start /w vs_buildtools.exe --quiet --wait --norestart --nocache \
    --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools" \
    --add Microsoft.VisualStudio.Workload.VCTools \
    --add Microsoft.VisualStudio.Component.VC.ASAN \
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
    --add Microsoft.VisualStudio.Component.Windows10SDK.19041 \
    || IF "%ERRORLEVEL%"=="3010" EXIT 0) \
    && del /q vs_buildtools.exe

# Install Chocolatey.
ENV chocolateyVersion=1.4.0
RUN powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"

# Install git.
RUN choco install git.install -y
RUN powershell Copy-Item -Recurse -Path 'C:\Program Files\Git' -Destination C:\Git

# Install vcpkg.
# hadolint ignore=DL3003
RUN powershell git clone https://github.com/microsoft/vcpkg.git \
    && cd vcpkg \
    && git fetch --all \
    && git checkout 2025.03.19 \
    && .\bootstrap-vcpkg.bat

ADD vcpkg/vcpkg.json .

RUN powershell .\vcpkg\vcpkg.exe install --x-install-root .\vcpkg\installed

# Install Azul Java 8 JDK.
RUN powershell Invoke-WebRequest -URI https://cdn.azul.com/zulu/bin/zulu8.62.0.19-ca-jdk8.0.332-win_x64.zip -OutFile $Env:TEMP\zulu8.62.0.19-ca-jdk8.0.332-win_x64.zip
RUN powershell Expand-Archive -Path $Env:TEMP\zulu8.62.0.19-ca-jdk8.0.332-win_x64.zip -DestinationPath "C:\Java"

# Install Apache Maven.
RUN powershell Invoke-WebRequest -URI https://archive.apache.org/dist/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.zip -OutFile $Env:TEMP\apache-maven-3.9.11-bin.zip
RUN powershell Expand-Archive -Path $Env:TEMP\apache-maven-3.9.11-bin.zip -DestinationPath "C:\Maven"

# Install CMake 3.19.0.
RUN powershell Invoke-WebRequest -URI https://cmake.org/files/v3.19/cmake-3.19.0-win64-x64.zip -OutFile $Env:TEMP\cmake-3.19.0-win64-x64.zip
RUN powershell Expand-Archive -Path $Env:TEMP\cmake-3.19.0-win64-x64.zip -DestinationPath "C:\CMake"

# Install zstd 1.5.4.
RUN powershell Invoke-WebRequest -Uri https://github.com/facebook/zstd/releases/download/v1.5.4/zstd-v1.5.4-win64.zip -OutFile $Env:TEMP\zstd-v1.5.4-win64.zip
RUN powershell Expand-Archive -Path $Env:TEMP\zstd-v1.5.4-win64.zip -DestinationPath "C:\ZStd"
RUN setx PATH "%PATH%;C:\ZStd"

# Install libopenssl 3.5.2-1 needed for rsync 3.2.7.
RUN powershell Invoke-WebRequest -Uri https://repo.msys2.org/msys/x86_64/libopenssl-3.5.2-1-x86_64.pkg.tar.zst -OutFile $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar.zst
RUN powershell zstd -d $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar.zst -o $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar
RUN powershell mkdir "C:\LibOpenSSL"
RUN powershell tar -xvf $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar -C "C:\LibOpenSSL"

# Install libxxhash 0.8.3 needed for rsync 3.2.7.
RUN powershell Invoke-WebRequest -Uri https://repo.msys2.org/msys/x86_64/libxxhash-0.8.3-1-x86_64.pkg.tar.zst -OutFile $Env:TEMP\libxxhash-0.8.3-1-x86_64.pkg.tar.zst
RUN powershell zstd -d $Env:TEMP\libxxhash-0.8.3-1-x86_64.pkg.tar.zst -o $Env:TEMP\libxxhash-0.8.3-1-x86_64.pkg.tar
RUN powershell mkdir "C:\LibXXHash"
RUN powershell tar -xvf $Env:TEMP\libxxhash-0.8.3-1-x86_64.pkg.tar -C "C:\LibXXHash"

# Install libzstd 1.5.4 needed for rsync 3.2.7.
RUN powershell Invoke-WebRequest -Uri https://repo.msys2.org/msys/x86_64/libzstd-1.5.5-1-x86_64.pkg.tar.zst -OutFile $Env:TEMP\libzstd-1.5.5-1-x86_64.pkg.tar.zst
RUN powershell zstd -d $Env:TEMP\libzstd-1.5.5-1-x86_64.pkg.tar.zst -o $Env:TEMP\libzstd-1.5.5-1-x86_64.pkg.tar
RUN powershell mkdir "C:\LibZStd"
RUN powershell tar -xvf $Env:TEMP\libzstd-1.5.5-1-x86_64.pkg.tar -C "C:\LibZStd"

# Install rsync 3.2.7.
RUN powershell Invoke-WebRequest -Uri https://repo.msys2.org/msys/x86_64/rsync-3.2.7-2-x86_64.pkg.tar.zst -OutFile $Env:TEMP\rsync-3.2.7-2-x86_64.pkg.tar.zst
RUN powershell zstd -d $Env:TEMP\rsync-3.2.7-2-x86_64.pkg.tar.zst -o $Env:TEMP\rsync-3.2.7-2-x86_64.pkg.tar
RUN powershell mkdir "C:\RSync"
RUN powershell tar -xvf $Env:TEMP\rsync-3.2.7-2-x86_64.pkg.tar -C "C:\RSync"
# Copy the dependencies of rsync 3.2.7.
RUN powershell Copy-Item -Path "C:\LibOpenSSL\usr\bin\*.dll" -Destination "C:\Program` Files\Git\usr\bin"
RUN powershell Copy-Item -Path "C:\LibXXHash\usr\bin\*.dll" -Destination "C:\Program` Files\Git\usr\bin"
RUN powershell Copy-Item -Path "C:\LibZStd\usr\bin\*.dll" -Destination "C:\Program` Files\Git\usr\bin"
RUN powershell Copy-Item -Path "C:\RSync\usr\bin\*" -Destination "C:\Program` Files\Git\usr\bin"

COPY pkg-resolver pkg-resolver

## Install Python 3.11.8.
# The Python installation steps below are derived from -
# https://github.com/docker-library/python/blob/105d6f34e7d70aad6f8c3e249b8208efa591916a/3.11/windows/windowsservercore-ltsc2022/Dockerfile
ENV PYTHONIOENCODING UTF-8
ENV PYTHON_VERSION 3.11.8
ENV PYTHON_PIP_VERSION 24.0
ENV PYTHON_SETUPTOOLS_VERSION 65.5.1
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/dbf0c85f76fb6e1ab42aa672ffca6f0a675d9ee4/public/get-pip.py
ENV PYTHON_GET_PIP_SHA256 dfe9fd5c28dc98b5ac17979a953ea550cec37ae1b47a5116007395bfacff2ab9
RUN powershell Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
RUN powershell pkg-resolver\install-python.ps1
RUN powershell pkg-resolver\install-pip.ps1
RUN powershell pip install python-dateutil

## Install the Microsoft Visual C++ 2010 Redistributable to link leveldbjni native library
RUN powershell -Command Invoke-WebRequest -Uri https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe -OutFile vcredist_x64.exe
RUN powershell -Command Start-Process -FilePath .\vcredist_x64.exe -ArgumentList '/quiet', '/norestart' -Wait
RUN powershell -Command Remove-Item vcredist_x64.exe

# Create a user HadoopBuilder with basic privileges and use it for building Hadoop on Windows.
RUN powershell New-LocalUser -Name 'HadoopBuilder' -Description 'User account for building Apache Hadoop' -Password ([securestring]::new()) -AccountNeverExpires -PasswordNeverExpires

# Grant the privilege to create symbolic links to HadoopBuilder.
RUN powershell secedit /export /cfg "C:\secpol.cfg"
RUN powershell "(Get-Content C:\secpol.cfg).Replace('SeCreateSymbolicLinkPrivilege = ', 'SeCreateSymbolicLinkPrivilege = HadoopBuilder,') | Out-File C:\secpol.cfg"
RUN powershell secedit /configure /db "C:\windows\security\local.sdb" /cfg "C:\secpol.cfg"
RUN powershell Remove-Item -Force "C:\secpol.cfg" -Confirm:$false

# Login as HadoopBuilder and set the necessary environment and PATH variables.
USER HadoopBuilder
ENV PROTOBUF_HOME "C:\vcpkg\installed\x64-windows"
ENV JAVA_HOME "C:\Java\zulu8.62.0.19-ca-jdk8.0.332-win_x64"
ENV MAVEN_OPTS '-Xmx2048M -Xss128M'
ENV IS_WINDOWS 1
RUN setx PATH "%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
RUN setx PATH "%PATH%;%JAVA_HOME%\bin"
RUN setx PATH "%PATH%;C:\Maven\apache-maven-3.9.11\bin"
RUN setx PATH "%PATH%;C:\CMake\cmake-3.19.0-win64-x64\bin"
RUN setx PATH "%PATH%;C:\ZStd"
RUN setx PATH "%PATH%;C:\Program Files\Git\usr\bin"
RUN setx PATH "%PATH%;C:\Python"

# The mvnsite module runs a bash script and somewhere down in the invocation, it resorts to call
# /usr/bin/env python3. Thus, we need to create the following symbolic link to satisfy this need.
RUN powershell New-Item -ItemType SymbolicLink -Path "C:\Python\python3" -Target "C:\Python\python.exe"

# We get strange Javadoc errors without this.
RUN setx classpath ""

# Setting Git configurations.
RUN git config --global core.autocrlf true
RUN git config --global core.longpaths true

# Define the entry point for the docker container.
ENTRYPOINT ["C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\VC\\Auxiliary\\Build\\vcvars64.bat", "&&", "cmd.exe"]
```

> You can notice that it uses jdk 8 to build hadoop, this is for compatibility of legacy code in hadoop. 
> Don't worry, even hadoop is build with jdk8, you can run it with jdk 11.

## 5. Use the docker image to build hadoop


**Do not mount the locally cloned Hadoop on the docker container**. This may cause `the build to fail owing to some
files not being able to be located by Maven`. Thus, we suggest cloning the Hadoop repository to a
non-mounted folder inside the container and proceed with the build. When the build is completed,
you may use the "docker cp" command to copy the built Hadoop tar.gz file from the docker container
to the host filesystem. If you still would like to mount the Hadoop codebase, a workaround would
be to copy the mounted Hadoop codebase into another folder (which doesn't point to a mount) in the
container's filesystem and use this for building.


### 5.1 Mount the maven repository

We noticed `no build issues` when the Maven repository from the host filesystem was mounted
into the container. This can greatly reduce the build time.

```powershell
docker run --rm -v D:\Maven\Repository:C:\Users\ContainerAdministrator\.m2\repository -it hadoop-windows-10-builder
```
> Assuming that the Maven repository is located at `D:\Maven\Repository` in the host filesystem
> 
> 
### 5.2 Keep the source path short

Keep the source code tree in a short path to avoid running into problems related
to Windows maximum path length limitation (for example, C:\hdc).

There is one support command file located in dev-support called `win-paths-eg.cmd`.
It should be copied somewhere convenient and modified to fit your needs.

`win-paths-eg.cmd` sets up the environment for use. You will need to modify this
file. It will put all the required components in the command path,
configure the bit-ness of the build, and set several optional components.

### 5.3 Handle the native lib requirements 

In the above `docker file`, you can notice that We use `vcpkg (https://github.com/microsoft/vcpkg.git)` for installing Boost, Protocol buffers,
OpenSSL and Zlib dependencies.

```DockerFile
RUN powershell git clone https://github.com/microsoft/vcpkg.git \
    && cd vcpkg \
    && git fetch --all \
    && git checkout 2025.03.19 \
    && .\bootstrap-vcpkg.bat

ADD vcpkg/vcpkg.json .

RUN powershell .\vcpkg\vcpkg.exe install --x-install-root .\vcpkg\installed
```

> Based on how the dependencies are installed, you need to set up the `environment variables` accordingly.

```powershell
# to avoid maven oom, you can increase the heap memory
set MAVEN_OPTS=-Xmx2048M -Xss128M

# (Assuming that vcpkg was checked out at C:\vcpkg)
set PROTOBUF_HOME=C:\vcpkg\installed\x64-windows

# If native code bindings for zlib are required, then the zlib headers must be
# deployed on the build machine. Set the ZLIB_HOME environment variable to the
# directory containing the headers.

set ZLIB_HOME=C:\zlib-1.2.7

# At runtime, zlib1.dll must be accessible on the PATH. Hadoop has been tested
# with zlib 1.2.7, built using Visual Studio 2010 out of contrib\vstudio\vc10 in
# the zlib 1.2.7 source tree.
```

> All Maven goals are the same as described above with the exception that
native code is built by enabling the 'native-win' Maven profile. -Pnative-win
is enabled by default when building on Windows since the native components
are required (not optional) on Windows.
```text


Build command:
The following command builds all the modules in the Hadoop project and generates the tar.gz file in
hadoop-dist/target upon successful build. Run these commands from an
"x64 Native Tools Command Prompt for VS 2019" which can be found under "Visual Studio 2019" in the
Windows start menu. If you're using the Docker image from Dockerfile_windows_10, you'll be
logged into "x64 Native Tools Command Prompt for VS 2019" automatically when you start the
container. The Docker image does not have a full VS install, so you need to add the
-Dskip.platformToolsetDetection option (already included below in the examples).

> set classpath=
> set PROTOBUF_HOME=C:\vcpkg\installed\x64-windows
> mvn clean package -Dhttps.protocols=TLSv1.2 -DskipTests -DskipDocs -Pnative-win,dist -Dskip.platformToolsetDetection^
    -Drequire.openssl -Drequire.test.libhadoop -Pyarn-ui -Dshell-executable=C:\Git\bin\bash.exe^
    -Dtar -Dopenssl.prefix=C:\vcpkg\installed\x64-windows^
    -Dcmake.prefix.path=C:\vcpkg\installed\x64-windows^
    -Dwindows.cmake.toolchain.file=C:\vcpkg\scripts\buildsystems\vcpkg.cmake -Dwindows.cmake.build.type=RelWithDebInfo^
    -Dwindows.build.hdfspp.dll=off -Dwindows.no.sasl=on -Duse.platformToolsetVersion=v142

Building the release tarball:
Assuming that we're still running in the Docker container hadoop-windows-10-builder, run the
following command to create the Apache Hadoop release tarball -

> set IS_WINDOWS=1
> set MVN_ARGS="-Dshell-executable=C:\Git\bin\bash.exe -Dhttps.protocols=TLSv1.2 -Pnative-win -Dskip.platformToolsetDetection -Drequire.openssl -Dopenssl.prefix=C:\vcpkg\installed\x64-windows -Dcmake.prefix.path=C:\vcpkg\installed\x64-windows -Dwindows.cmake.toolchain.file=C:\vcpkg\scripts\buildsystems\vcpkg.cmake -Dwindows.cmake.build.type=RelWithDebInfo -Dwindows.build.hdfspp.dll=off -Duse.platformToolsetVersion=v142 -Dwindows.no.sasl=on -DskipTests -DskipDocs -Drequire.test.libhadoop"
> C:\Git\bin\bash.exe C:\hadoop\dev-support\bin\create-release --mvnargs=%MVN_ARGS%

Note:
If the building fails due to an issue with long paths, rename the Hadoop root directory to just a
letter (like 'h') and rebuild -

> C:\Git\bin\bash.exe C:\h\dev-support\bin\create-release --mvnargs=%MVN_ARGS%

----------------------------------------------------------------------------------
Building distributions:

 * Build distribution with native code    : mvn package [-Pdist][-Pdocs][-Psrc][-Dtar][-Dmaven.javadoc.skip=true]

----------------------------------------------------------------------------------
Running compatibility checks with checkcompatibility.py

Invoke `./dev-support/bin/checkcompatibility.py` to run Java API Compliance Checker
to compare the public Java APIs of two git objects. This can be used by release
managers to compare the compatibility of a previous and current release.

As an example, this invocation will check the compatibility of interfaces annotated as Public or LimitedPrivate:

./dev-support/bin/checkcompatibility.py --annotation org.apache.hadoop.classification.InterfaceAudience.Public --annotation org.apache.hadoop.classification.InterfaceAudience.LimitedPrivate --include "hadoop.*" branch-2.7.2 trunk

----------------------------------------------------------------------------------
Changing the Hadoop version declared returned by VersionInfo

If for compatibility reasons the version of Hadoop has to be declared as a 2.x release in the information returned by
org.apache.hadoop.util.VersionInfo, set the property declared.hadoop.version to the desired version.
For example: mvn package -Pdist -Ddeclared.hadoop.version=2.11

If unset, the project version declared in the POM file is used.
```

## Use 