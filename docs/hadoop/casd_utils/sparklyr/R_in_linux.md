# R in linux 

Current stable R version in production in CASD is `4.2.2`. So in linux we will install 4.2.2 too.

For debian 13, the current R version is `4.5.0`. So we can't use the R from the default apt package repo.


## Build R from source


### Install Build Dependencies

Make sure you have the deb-src in your `/etc/apt/sources.list`

```shell
# open your sources.list
sudo nano /etc/apt/sources.list

# expected content
deb http://deb.debian.org/debian/ trixie main
deb-src http://deb.debian.org/debian/ trixie main

deb http://security.debian.org/debian-security trixie-security main
deb-src http://security.debian.org/debian-security trixie-security main

deb http://deb.debian.org/debian/ trixie-updates main
deb-src http://deb.debian.org/debian/ trixie-updates main
```

Install the dependencies 

```shell
# Update your apt repo cache
sudo apt update

# install all dependencies for build `r-base`
sudo apt build-dep r-base

# install some other packages
sudo apt install libreadline-dev libxt-dev libpcre2-dev libcurl4-openssl-dev
```

### Download and Extract R 4.2.2

```shell
cd ~

wget https://cran.r-project.org/src/base/R-4/R-4.2.2.tar.gz
tar -xzvf R-4.2.2.tar.gz
cd R-4.2.2

```

### Configure and Build


```shell
# simple config
./configure --enable-R-shlib --with-blas --with-lapack
```

> This may fail, because debian 13 uses modern package versions, but the make file uses old package version. In my
> case, I had `error: libcurl >= 7.28.0 library and headers are required with support for https`

If you goto check the `config.log` with the `grep -A 5 "checking if libcurl is version 7 and >= 7.28.0" config.log`, 
you will find the below log messages:

```text
configure:47587: checking if libcurl is version 7 and >= 7.28.0
configure:47618: gcc -o conftest -g -O2 -fpic -I/usr/local/include -L/usr/lib/x86_64-linux-gnu -lcurl -lssl -lcrypto conftest.c -lcurl -lpcre2-8 -llzma -lbz2 -lz -ltirpc -lrt -ldl -lm -licuuc -licui18n >&5
configure:47618: $? = 0 # this line means The compiler successfully built the test program ($? = 0)

configure:47618: ./conftest

configure:47618: $? = 1 # this line means when the script tried to run that test program to check the version, it crashed or returned a failure ($? = 1).

configure: program exited with status 1 in config.log

```

So the real cause is the `configure` script uses an outdated method to check the libcurl version that is 
designed for `libcurl 7.x`, but in debian 13 the libcurl version is `8.x` which is not compatible with the script.

To bypass this, we can use the below command to ignor the error

```shell
./configure \
  --enable-R-shlib \
  --with-blas \
  --with-lapack \
  --with-libcurl \
  r_cv_have_curl728=yes
```

Once configure finally finishes without an error, proceed with the build.
```shell
# the option -j$(nproc) will use all your CPU cores to speed up the build process
make -j$(nproc)

# Install the R to a specific path
# It is best to install it to /opt so it doesn't conflict with the system's default R.
sudo make install prefix=/opt/R/4.2.2


# Create a Symlink
sudo ln -s /opt/R/4.2.2/bin/R /usr/local/bin/R

# check the R version
R --version

# expected output
R version 4.2.2 (2022-10-31) -- "Innocent and Trusting"
Copyright (C) 2022 The R Foundation for Statistical Computing
Platform: x86_64-pc-linux-gnu (64-bit)
```
