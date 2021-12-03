FROM hashicorp/terraform:1.0.10 as terraform

FROM amazon/aws-cli:2.3.4 as aws

FROM golang:1.17.3-stretch as go

RUN GO111MODULE=on go get github.com/raviqqe/liche

FROM debian:stable-slim

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
  &&  apt-get install -y --no-install-recommends \
  git make openssh-client curl unzip locales \
  default-mysql-client \
  python3-minimal ruby \
  && apt-get clean autoclean \
  && apt-get autoremove -y --purge \
  && rm -rf /var/lib/apt/lists/*

RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen\
  && echo "LANG=en_US.UTF-8" > /etc/locale.conf\
  && locale-gen en_US.UTF-8

ENV LANG "en_US.UTF-8"
ENV LANGUAGE "en_US.UTF-8"
ENV LC_ALL "en_US.UTF-8"

RUN gem install \
  my_obfuscate

COPY --from=aws /usr/local/aws-cli /usr/local/aws-cli

ENV AWS_BIN /usr/local/aws-cli/v2/current/bin
ENV PATH "$AWS_BIN:$PATH"

COPY --from=terraform /bin/terraform /usr/bin

ENV GO_BIN /go/bin
ENV PATH "$GO_BIN:$PATH"

COPY --from=go /go/bin $GO_BIN

ENV BIN_3SCALE /opt/3scale/bin
ENV PATH "$BIN_3SCALE:$PATH"

ADD bin/ $BIN_3SCALE
RUN chmod -R 0755 $BIN_3SCALE
