# Protobuf in hadoop

Hadoop is a distributed system writen in JAVA. When a hadoop client wants to read a file in the cluster, it doesn't just send 
the raw text, it sends a `structured Request object` to the cluster. To do this correctly, we need:

- `Serialization`: Because binary format data travels fast over the network.
- `Cross-Language Compatibility`: The tool must support multi-language.
- `Interface Definition`: To standard the communication, we need a universal interface definition format.

## why protobuf?

Protobuf converts complex Java or C++ objects into a compact binary format(`Serialization`). 
Protobuf provides Java lib and C++ lib. The Hadoop server is usually Java, but the Native Client(Windows client) maybe in C++. 
Protobuf allows the C++ code (libhdfs) to understand the exact same message structure that the Java NameNode sends.
Protobuf provide an interface definition format(.proto files) which allows different module to communicate.