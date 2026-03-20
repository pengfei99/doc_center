# JAVA env introduction

## 1. JRE VS JDK

## 2. Which JDK is better?

As you know there are many jdks distributions, which one you need to choose?

Below are some major jdks distributions
### 2.1 Eclipse Temurin (by Adoptium / Eclipse Foundation)
The best general-purpose choice for most developers and companies in 2026

- Completely free
- TCK-tested & certified
- Excellent update frequency for security & bug fixes
- Very wide platform support
- Huge community & CI/CD ecosystem trust
- Download: https://adoptium.net/

### 2.2 Azul Zulu

Excellent alternative — often #1 or #2 recommendation
- Free community edition (very good)
- Paid enterprise support available (usually cheaper & longer than Oracle)
- Very good for long-term Java 8 / 11 / 17 / 21 support
- Strong in low-latency & large-heap scenarios (if you buy Platform Prime)

### 2.3 Amazon Corretto
Great if you're already in AWS
- Free, long-term support (especially Java 8, 11, 17, 21)
- AWS-optimized patches

### 2.4 BellSoft Liberica
Very good if you need JavaFX, embedded, ARM32, or exotic platforms

### 2.5 Microsoft Build of OpenJDK
Good if you're deep in Azure ecosystem

### 2.6 Oracle JDK
Only if:
- Your company already has an Oracle contract
- You need official Oracle premier support tied to other Oracle products
> Very few new projects choose it in 2026 due to cost

### 2.7 Plain OpenJDK from jdk.java.net
Only for experiments or when you want the absolute newest features
> Short support window → not suitable for production
> 
### 2.8 Bottom Line – What Should You Use?

- Individual developer, student, hobby: Eclipse Temurin
- Small–medium company, server/backend: Eclipse Temurin or Azul Zulu
- Large enterprise wanting support: Azul Zulu (Enterprise) or Red Hat
- AWS-heavy environment: Amazon Corretto
- Already paying Oracle a lot: Oracle JDK (but consider migrating)
- Need longest possible Java 8/11 support: Azul Zulu or Liberica
- Just testing something quickly: Oracle OpenJDK or Temurin