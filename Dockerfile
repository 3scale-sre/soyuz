FROM hashicorp/terraform:1.3.5 as terraform

FROM amazon/aws-cli:2.8.13 as aws

FROM regclient/regctl:edge-alpine as regctl

FROM golang:1.19.3-bullseye as go

RUN GO111MODULE=on go install github.com/raviqqe/liche@latest

FROM alpine:3.17 as gh

ENV GITHUB_CLI_VERSION=2.0.0
RUN if [ $(uname -m) == "aarch64" ]; then ARCH=arm64; else ARCH=amd64; fi; \
  wget -O /tmp/gh.tgz https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_${ARCH}.tar.gz && \
  tar --strip-components=2 --extract --file /tmp/gh.tgz \
  gh_${GITHUB_CLI_VERSION}_linux_${ARCH}/bin/gh && mv -v gh /bin/gh

FROM alpine:3.17 as yq

ENV VERSION=v4.30.5
RUN if [ $(uname -m) == "aarch64" ]; then ARCH=arm64; else ARCH=amd64; fi; \
  wget -O /tmp/yq.tgz  https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_${ARCH}.tar.gz  && \
  tar --extract --file /tmp/yq.tgz \
  ./yq_linux_${ARCH} && mv -v yq_linux_${ARCH} /bin/yq

FROM gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/git-init:v0.45.0 as git-init

FROM debian:12.4-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -yq && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -yq \
  git make openssh-client curl wget jq gnupg pigz unzip locales lsb-release \
  python3-minimal python3-boto3 \
  ruby && \
  find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete

RUN TEMP_DEB="$(mktemp)" && \
  wget -O "$TEMP_DEB" 'https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb' && \
  dpkg -i "$TEMP_DEB" && rm -f "$TEMP_DEB" && \
  apt-get update -yq && apt-get install -yq mysql-community-client  && \
  find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete

RUN \
  echo "LC_ALL=en_US.UTF-8" >>/etc/environment && \
  echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen && \
  echo "LANG=en_US.UTF-8" >/etc/locale.conf && \
  locale-gen en_US.UTF-8

ENV LANG "en_US.UTF-8"
ENV LANGUAGE "en_US.UTF-8"
ENV LC_ALL "en_US.UTF-8"

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

ENV GO_BIN /go/bin
ENV PATH "$GO_BIN:$PATH"

COPY --from=go /go/bin $GO_BIN

ENV BIN_3SCALE /opt/3scale/bin
ENV PATH "$BIN_3SCALE:$PATH"

ADD bin/ $BIN_3SCALE
RUN chmod -R 0755 $BIN_3SCALE
