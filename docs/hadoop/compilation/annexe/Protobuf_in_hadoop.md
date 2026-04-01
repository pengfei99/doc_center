# Protobuf in hadoop

Hadoop is a distributed system writen in JAVA. Hadoop module(e.g. HDFS, YARN, and MapReduce) relies on `Protobuf` 
primarily for internal `RPC (Remote Procedure Call) communication` between its components 
To do this correctly, we need:

- `Serialization`: Because binary format data travels fast over the network.
- `Cross-Language Compatibility`: The tool must support multi-language.
- `Interface Definition`: To standard the communication, we need a universal interface definition format.

## why protobuf?

Protobuf converts complex Java or C++ objects into a compact binary format(`Serialization`). 
Protobuf provides Java lib and C++ lib. The Hadoop server is usually Java, but the Native Client(Windows client) maybe in C++. 
Protobuf allows the C++ code (libhdfs) to understand the exact same message structure that the Java NameNode sends.
Protobuf provide an interface definition format(.proto files) which allows different module to communicate.


## Install protobuf in windows

Go to: https://github.com/protocolbuffers/protobuf/releases/tag/v25.5
Find the file `protoc-25.5-win64.zip` (note the version tag is v25.5, not 3.25.5 in the filename).

Download `protoc-25.5-win64.zip` from GitHub and extract the zip into `C:\Protobuf\3.25.5\`.

Your final structure should look like:
```text
C:\Protobuf\3.25.5\
├── protoc.exe
└── include\   (optional)

```
Step 3: Add protoc to System PATH

Right-click This PC → Properties → Advanced system settings → Environment Variables.
Under System variables, Create a new variable `PROTO_HOME` with value `C:\Protobuf\3.25.5`

Then find and edit `Path` by adding `%PROTO_HOME%\bin` in it. Click OK on all windows.

Open a new Command Prompt (important: new window) and verify:
```powershell
protoc --version
#You should see:
libprotoc 25.5
```

## Set protobuf Environment Variable for hadoop build (Important!)

Hadoop’s Maven build looks for the `protoc binary` using the property `HADOOP_PROTOC_PATH`.
Run this in the Command Prompt where you will build Hadoop:

```powershell
set HADOOP_PROTOC_PATH=C:\Protobuf\3.25.5\protoc.exe
```
