FROM quay.io/minio/minio:RELEASE.2022-10-15T19-57-03Z
RUN apk update & apk add ca-certificates
COPY ca.crt /usr/local/share/ca-certificates/ca.crt
RUN update-ca-certificates