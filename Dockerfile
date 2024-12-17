FROM hashicorp/terraform:1.3.5 as terraform

FROM amazon/aws-cli:2.8.13 as aws

FROM regclient/regctl:edge-alpine as regctl

FROM golang:1.19.3-bullseye as go

RUN GO111MODULE=on go install -v -x -a github.com/raviqqe/liche@latest

FROM gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/git-init:v0.45.0 as git-init

FROM alpine:3.20 as kubectl

ENV VERSION="v1.32.0"
ENV BINARY="/bin/kubectl"

RUN if [ $(uname -m) == "aarch64" ]; then ARCH="arm64"; else ARCH="amd64"; fi; \
  wget -q "https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubectl" -O ${BINARY}

FROM alpine:3.20 as PolicyGenerator

ENV VERSION="v1.16.0"
ENV REGISTRY="open-cluster-management-io/policy-generator-plugin"
ENV BINARY="/bin/PolicyGenerator"

RUN if [ $(uname -m) == "aarch64" ]; then ARCH="arm64"; else ARCH="amd64"; fi; \
  wget -q "https://github.com/${REGISTRY}/releases/download/${VERSION}/linux-${ARCH}-PolicyGenerator" -O ${BINARY}

FROM alpine:3.20 as gh

ENV GITHUB_CLI_VERSION=2.0.0
RUN if [ $(uname -m) == "aarch64" ]; then ARCH=arm64; else ARCH=amd64; fi; \
  wget -O /tmp/gh.tgz https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_${ARCH}.tar.gz && \
  tar --strip-components=2 --extract --file /tmp/gh.tgz \
  gh_${GITHUB_CLI_VERSION}_linux_${ARCH}/bin/gh && mv -v gh /bin/gh

FROM alpine:3.20 as yq

ENV VERSION=v4.30.5
RUN if [ $(uname -m) == "aarch64" ]; then ARCH=arm64; else ARCH=amd64; fi; \
  wget -O /tmp/yq.tgz  https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_${ARCH}.tar.gz  && \
  tar --extract --file /tmp/yq.tgz \
  ./yq_linux_${ARCH} && mv -v yq_linux_${ARCH} /bin/yq

FROM alpine:3.20 as mysql

RUN if [ $(uname -m) == "aarch64" ]; then ARCH=aarch64; else ARCH=x86_64; fi; \
  wget -O /tmp/mysql.tgz  https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.39-linux-glibc2.28-${ARCH}.tar.xz && \
  tar --extract --file /tmp/mysql.tgz &&  \
  install -m 775 ./mysql-8.0.39-linux-glibc2.28-${ARCH}/bin/mysql /bin/mysql && \
  install -m 775 ./mysql-8.0.39-linux-glibc2.28-${ARCH}/bin/mysqldump /bin/mysqldump


FROM debian:12.4-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -yq && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -yq \
  git make openssh-client curl wget jq locales lsb-release \
  gnupg pigz unzip xz-utils \
  python3-minimal python3-boto3 \
  ruby && \
  find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete

RUN \
  echo "LC_ALL=en_US.UTF-8" >>/etc/environment && \
  echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen && \
  echo "LANG=en_US.UTF-8" >/etc/locale.conf && \
  locale-gen en_US.UTF-8

ENV LANG "en_US.UTF-8"
ENV LANGUAGE "en_US.UTF-8"
ENV LC_ALL "en_US.UTF-8"

COPY --from=mysql /bin/mysql /usr/local/bin
COPY --from=mysql /bin/mysqldump /usr/local/bin

RUN gem install \
  my_obfuscate

COPY --from=aws /usr/local/aws-cli /usr/local/aws-cli

ENV AWS_BIN /usr/local/aws-cli/v2/current/bin
ENV PATH "$AWS_BIN:$PATH"

COPY --from=git-init /ko-app/git-init /usr/local/bin

COPY --from=terraform /bin/terraform /usr/local/bin

COPY --from=regctl /usr/local/bin/regctl /usr/local/bin

COPY --from=gh /bin/gh /usr/local/bin

COPY --from=yq /bin/yq /usr/local/bin

COPY --from=kubectl --chmod=775 /bin/kubectl /usr/local/bin

ENV KUSTOMIZE_PLUGIN_HOME /opt/kustomize/plugin

COPY --from=PolicyGenerator --chmod=775 /bin/PolicyGenerator \
  /opt/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator/PolicyGenerator

# ENV GO_BIN /go/bin
# ENV PATH "$GO_BIN:$PATH"

# COPY --from=go /go/bin $GO_BIN

ENV BIN_3SCALE /opt/3scale/bin
ENV PATH "$BIN_3SCALE:$PATH"

ADD bin/ $BIN_3SCALE
RUN chmod -R 0755 $BIN_3SCALE
