FROM hashicorp/terraform:1.17.2 AS terraform

FROM amazon/aws-cli:2.42.2 AS aws

FROM regclient/regctl:v0.11.7 AS regctl

FROM alpine:3.23 AS kubectl

ENV VERSION="v1.37.2"
ENV BINARY="/bin/kubectl"

RUN if [ $(uname -m) == "aarch64" ]; then ARCH="arm64"; else ARCH="amd64"; fi; \
  wget -q "https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubectl" -O ${BINARY}

# Built from source: the published release binaries are linked against an
# older Go toolchain and keep inheriting its stdlib CVEs.
FROM golang:1.27-alpine AS policygenerator

ENV VERSION="v1.19.0"

RUN apk add --no-cache git && \
  git clone --depth 1 --branch ${VERSION} \
    https://github.com/open-cluster-management-io/policy-generator-plugin.git /src && \
  cd /src && \
  go get golang.org/x/net@v0.62.0 golang.org/x/text@v0.44.0 && \
  CGO_ENABLED=0 go build -trimpath -o /bin/PolicyGenerator ./cmd/PolicyGenerator && \
  chmod 775 /bin/PolicyGenerator

FROM alpine:3.23 AS gh

ENV GITHUB_CLI_VERSION=2.105.0
RUN if [ $(uname -m) == "aarch64" ]; then ARCH=arm64; else ARCH=amd64; fi; \
  wget -O /tmp/gh.tgz https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_${ARCH}.tar.gz && \
  tar --strip-components=2 --extract --file /tmp/gh.tgz \
  gh_${GITHUB_CLI_VERSION}_linux_${ARCH}/bin/gh && mv -v gh /bin/gh

FROM alpine:3.23 AS yq

ENV VERSION=v4.54.3
RUN if [ $(uname -m) == "aarch64" ]; then ARCH=arm64; else ARCH=amd64; fi; \
  wget -O /tmp/yq.tgz  https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_${ARCH}.tar.gz  && \
  tar --extract --file /tmp/yq.tgz \
  ./yq_linux_${ARCH} && mv -v yq_linux_${ARCH} /bin/yq

FROM alpine:3.23 AS mysql

RUN if [ $(uname -m) == "aarch64" ]; then ARCH=aarch64; else ARCH=x86_64; fi; \
  wget -O /tmp/mysql.tgz  https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.39-linux-glibc2.28-${ARCH}.tar.xz && \
  tar --extract --file /tmp/mysql.tgz &&  \
  install -m 775 ./mysql-8.0.39-linux-glibc2.28-${ARCH}/bin/mysql /bin/mysql && \
  install -m 775 ./mysql-8.0.39-linux-glibc2.28-${ARCH}/bin/mysqldump /bin/mysqldump

# Ruby is not taken from Debian: bookworm ships ruby 3.1 whose default gems
# (erb, uri, time, net-imap, rexml) are frozen at vulnerable versions and are
# never updated by the distro. The upstream ruby image keeps them current.
FROM ruby:3.4-slim-bookworm AS ruby

RUN GEM_HOME=/usr/local/lib/ruby/gems/3.4.0 \
    GEM_PATH=/usr/local/lib/ruby/gems/3.4.0 \
    gem install --no-document my_obfuscate


FROM debian:12-slim

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update -yq && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -yq \
  git make openssh-client curl wget jq locales lsb-release \
  gnupg pigz unzip zip xz-utils \
  python3-minimal python3-boto3 \
  libyaml-0-2 libgmp10 libffi8 libncurses6 && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get -yq full-upgrade && \
  find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete

RUN \
  echo "LC_ALL=en_US.UTF-8" >>/etc/environment && \
  echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen && \
  echo "LANG=en_US.UTF-8" >/etc/locale.conf && \
  locale-gen en_US.UTF-8

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8"
ENV LC_ALL="en_US.UTF-8"

COPY --from=mysql /bin/mysql /usr/local/bin
COPY --from=mysql /bin/mysqldump /usr/local/bin

COPY --from=ruby /usr/local /usr/local

COPY --from=aws /usr/local/aws-cli /usr/local/aws-cli

ENV AWS_BIN="/usr/local/aws-cli/v2/current/bin"
ENV PATH="$AWS_BIN:$PATH"

COPY --from=terraform /bin/terraform /usr/local/bin

COPY --from=regctl /regctl /usr/local/bin

COPY --from=gh /bin/gh /usr/local/bin

COPY --from=yq /bin/yq /usr/local/bin

COPY --from=kubectl --chmod=775 /bin/kubectl /usr/local/bin

ENV KUSTOMIZE_PLUGIN_HOME="/opt/kustomize/plugin"

COPY --from=policygenerator --chmod=775 /bin/PolicyGenerator \
  /opt/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator/PolicyGenerator

ENV BIN_3SCALE="/opt/3scale/bin"
ENV PATH="$BIN_3SCALE:$PATH"

ADD bin/ $BIN_3SCALE
RUN chmod -R 0755 $BIN_3SCALE
