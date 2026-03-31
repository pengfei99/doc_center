# Compile hadoop on Windows server 2019

In this tutorial, we will install all required libs and tools to compile hadoop on a Windows 2019 server. This is
a bare metal installation. If you want to have a portal build env, you can check the docker image approach.

> With the bare metal approach, you need to have `admin rights` to install certain tools.

## Install git

Git is the center of build environment, so pay extra attention of this section.

Here we recommend you to use the [git official Winodws installer](https://git-scm.com/install/windows).
You can not choose where you install the git binaries, it's automatically installed at `C:\Program Files\Git\`.

But for some hadoop maven build target, it uses `git bash` and it only searches git bash at `C:\Git\bin\bash`. If it 
does not exist, the maven build will fail. So the simplest solution is to finish all the git installation and copy  
`C:\Program Files\Git\` to `C:\Git\`

> You just follow the Windows installer to finish the installation. Note the installation of git is not finished yet
> We will add more libs into Git folder. You will see how in the following sections.

## Install Visual studio

```powershell
#
cd C:\Users\pliu.CASDDS.000\Documents\temp

# download vs_buildtoos
curl -SL --output vs_buildtools.exe https://aka.ms/vs/16/release/vs_buildtools.exe


# add plugins
vs_buildtools.exe --quiet --wait --norestart --nocache --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.ASAN --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041

```

## Install vcpkg

`vcpkg` is a free and open-source C/C++ package manager maintained by Microsoft and the C++ community. You can find their
repo git [here](https://github.com/microsoft/vcpkg)

```powershell
cd C:\Users\pliu.CASDDS.000\Documents\temp

git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
git fetch --all
# you can replace the current realse by any new release
git checkout 2026.03.18 
# init vcpkg and disabe telemetry
.\bootstrap-vcpkg.bat -disableMetrics

```

### Install the c++ packages and headers via vcpkg
To avoid installing these libs one by one, we can use a `vcpkg.json` file to specify all the required packages

Copy the `vcpkg.json` file into `C:\Users\pliu.CASDDS.000\Documents\temp`

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg.schema.json",
  "dependencies": [
    "boost",
    "protobuf",
    "openssl",
    "zlib"
  ],
  "builtin-baseline": "289a69379604112a433874fe8b9812dad3103341",
  "overrides": [
    {
      "name": "protobuf",
      "version": "3.21.12",
      "port-version": 4
    }
  ]
}
```

Now you can install

```powershell
cd C:\Users\pliu.CASDDS.000\Documents\temp
# 
.\vcpkg\vcpkg.exe install --x-install-root .\vcpkg\installed

.\vcpkg.exe install --x-install-root .\installed
```
### Setup env vars

After the vcpkg installed all the libs, you need to set up env vars. For example the `HDFS native client` requires 
`vcpkg` to be fully "integrated" so that `msbuild` can find the `headers for OpenSSL and Protobuf`.

```powershell
set VCPKG_ROOT=C:\vcpkg
set OPENSSL_ROOT_DIR=C:\vcpkg\installed\x64-windows
set PROTOBUF_LIBRARY=C:\vcpkg\installed\x64-windows\lib\libprotobuf.lib
set PROTOBUF_INCLUDE_DIR=C:\vcpkg\installed\x64-windows\include
```

## Install java
You can download the required jdk from this website
https://www.azul.com/downloads/?version=java-11-lts&os=windows&architecture=x86-64-bit&package=jdk#zulu
Then you need to setup JAVA_HOME and path

```powershell
# put the java source in this folder
C:\Java\jdk11.0.30-win_x64

# check java version
java --version

# check java bin location
where java
```

## Install maven

Download maven from this website https://archive.apache.org/dist/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.zip

Then you need to set up MAVEN_HOME and path

```powershell
# put the maven source in this folder
C:\Maven\apache-maven-3.9.11

# check maven version
mvn --verison
```

> add new row with %MAVEN_HOME%\bin in path

## Install cmake
Download cmake from this website https://cmake.org/files/v3.19/cmake-3.19.8-win64-x64.zip

Then you need to set up CMAKE_HOME and path

```powershell
# put the camke source in this folder
C:\Cmake\cmake-3.19.8-win64-x64\

# check
cmake --version
```

## Install zstd tool

Download zstd tool from this website
https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-v1.5.6-win64.zip

Then you need to set up ZSTD_HOME and path
```powershell
# put the zstd source in this folder
C:\Zstd\zstd-v1.5.6-win64

# check zstd version
zstd --version
```

> add new row with %ZSTD_HOME% in path


## Install rsync and its dependencies for git

Download the below libs
https://repo.msys2.org/msys/x86_64/libopenssl-3.5.2-1-x86_64.pkg.tar.zst
```powershell
# download libopenssl
Invoke-WebRequest -Uri https://repo.msys2.org/msys/x86_64/libopenssl-3.5.2-1-x86_64.pkg.tar.zst -OutFile $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar.zst
# unzip
zstd -d $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar.zst -o $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar
# untar
tar -xvf $Env:TEMP\libopenssl-3.5.2-1-x86_64.pkg.tar -C "C:\LibOpenSSL
```

## Install python and pip

```powershell
# download and run the installation script
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"; &"./install-pyenv-win.ps1"

# close and reopen a powershell, check the intalled pyenv version
pyenv --version

# list available python version
pyenv install -l

# install a python 3.12
pyenv install 3.11

# set 3.11 as global python
pyenv global 3.11

# check python version
python -V

# check pip
pip --version
```

## Install Microsoft Visual C++ 2010 Redistributable

We use Microsoft Visual C++ 2010 Redistributable to link native library.

```powershell
Invoke-WebRequest -Uri https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe -OutFile vcredist_x64.exe

```

## Start the build process

### switch to the correct release branch

The hadoop project has a default branch called `trunk`, it contains the latest update of the project. To build for 
a specific release version, we need to switch to the dedicated release branch. The release branch has the general
form `rel/release-verion`, for example the `release 3.4.3` will be on branch `rel/release-3.4.3`

```powershell
git checkout rel/release-3.4.3
```


### Open a correct command prompt

You need to open a `Microsoft Visual Studio Developer Command Prompt` to start the build process
```powershell
# go to the visual studio folder
cd C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\BuildTools\\VC\\Auxiliary\\Build\\

# run the bat script
vcvars64.bat

# you should see something like the visuel studio dev prompt is activate.
**********************************************************************
** Visual Studio 2019 Developer Command Prompt v16.11.54
** Copyright (c) 2021 Microsoft Corporation
**********************************************************************
[vcvarsall.bat] Environment initialized for: 'x64'

cd C:\hadoop
```

### Check dependencies in your command prompt

Check dependencies before long maven run
```powershell
# check if msbuild exists
where msbuild
# expected output
C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe

# check version
msbuild -version

# expected output for msvs 2019, if you use other msvs, the ouput may be different
Microsoft (R) Build Engine version 16.11.6+a918ceb31 for .NET Framework
Copyright (C) Microsoft Corporation. All rights reserved.
16.11.6.22506

# check cmake
where cmake 

cmake --version

# expetecd output
cmake version 3.19.8

# check protobuf
where protoc

protoc --version
#expected output
libprotoc 3.21.12

# test cl
cl

# expected output
Microsoft (R) C/C++ Optimizing Compiler Version 19.29.30159 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

usage: cl [ option... ] filename... [ /link linkoption... ]

# test rc
where rc

# expected output
C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\rc.exe

# test bash
bash --version

# you should see
GNU bash, version 5.2.37(1)-release (x86_64-pc-msys)
Copyright (C) 2022 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>


# if you see the below output, it means your bash alias has conflict, you need to use -Dshell-executable=C:\Git\bin\bash.exe
# in your mvn command to avoid conflict.
Windows Subsystem for Linux has no installed distributions.
Distributions can be installed by visiting the Microsoft Store:
https://aka.ms/wslstore
```

### Run maven build command


```powershell
set classpath=
set IS_WINDOWS=1
set PROTOBUF_HOME=C:\vcpkg\installed\x64-windows

# the build command run all maven target
mvn clean package -e -X -DPlatform=x64 -Dwinutils.bitness=64 -DskipTests -DskipDocs -Dskip.native.tests=true -Dhadoop.test.skip.output=true -Dhttps.protocols=TLSv1.2  -Pnative-win,dist -Dskip.platformToolsetDetection -Drequire.openssl -Drequire.test.libhadoop -Pyarn-ui -Dshell-executable=C:\Git\bin\bash.exe -Dtar -Dopenssl.prefix=C:\vcpkg\installed\x64-windows ^
    -Dcmake.prefix.path=C:\vcpkg\installed\x64-windows -Dwindows.cmake.toolchain.file=C:\vcpkg\scripts\buildsystems\vcpkg.cmake -Dwindows.cmake.build.type=RelWithDebInfo "-Dopenssl.prefix=C:\vcpkg\installed\x64-windows" "-Dopenssl.include=C:\vcpkg\installed\x64-windows\include" "-Dopenssl.lib=C:\vcpkg\installed\x64-windows\lib" -Dwindows.build.hdfspp.dll=off -Dwindows.no.sasl=on -Duse.platformToolsetVersion=v142

# the build command run only the target hadoop-common
# the opition `-pl :hadoop-common` means only run hadoop-common
# the option ` -am` means run required target of hadoop-common
mvn clean package -pl :hadoop-common -am  -DPlatform=x64 -Dwinutils.bitness=64 -DskipTests -DskipDocs -Pnative-win,dist -Dtar -Dskip.native.tests=true ^
  -Dskip.platformToolsetDetection -Duse.platformToolsetVersion=v142 -Dcmake.prefix.path=C:\vcpkg\installed\x64-windows ^
  -Dwindows.cmake.toolchain.file=C:\vcpkg\scripts\buildsystems\vcpkg.cmake -Dshell-executable=C:\Git\bin\bash.exe
```

> Fot the complete build, the generated files can be found at `C:\hadoop\hadoop-dist\target\hadoop-common-3.4.3`

> For the hadoop-common build, the generated files can be found at `C:\hadoop\hadoop-common-project\hadoop-common\target\hadoop-common-3.4.3`

### Test the generated winutils and hadoop.dll

After the build, you can test the generated `winutils.exe` and `hadoop.dll`.

```powershell
# check native build of hadoop, if this failed, it means hadoop.dll has problems
hadoop checknative -a

# check winutils
winutils.exe ls

winutils.exe systeminfo

# expected output
22899888128,19947098112,17060904960,14197358592,4,3400000,77232781,0,0,1324034502,663915712
```
> The Comma separated list of values. 
> - VirtualMemorySize(bytes)
> - PhysicalMemorySize(bytes), 
> - FreeVirtualMemory(bytes),
> - FreePhysicalMemory(bytes),
> - NumberOfProcessors,
> - CpuFrequency(Khz), 
> - CpuTime(MilliSec,Kernel+User), 
> - DiskRead(bytes),
> - DiskWrite(bytes), 
> - NetworkRead(bytes),
> - NetworkWrite(bytes)

The hadoop client stack in windows is 

```text
Java Hadoop Client
        ↓
JNI (native bridge)
        ↓
hadoop.dll
        ↓
winutils.exe + Win32 API
        ↓
Windows OS
```
