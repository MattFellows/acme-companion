FROM arm32v7/golang AS go-builder

ENV DOCKER_GEN_VERSION=0.7.6

# Build docker-gen
RUN apt-get install git \
    && git clone https://github.com/jwilder/docker-gen \
    && cd /go/docker-gen \
    && git -c advice.detachedHead=false checkout $DOCKER_GEN_VERSION \
    && go mod download \
    && CGO_ENABLED=0 go build -ldflags "-X main.buildVersion=${VERSION}" -o docker-gen ./cmd/docker-gen \
    && go clean -cache \
    && mv docker-gen /usr/local/bin/ \
    && cd - \
    && rm -rf /go/docker-gen 

FROM arm32v7/alpine:3.13.5

LABEL maintainer="Nicolas Duchon <nicolas.duchon@gmail.com> (@buchdag)"

ARG GIT_DESCRIBE
ARG ACMESH_VERSION=2.8.8

ENV COMPANION_VERSION=$GIT_DESCRIBE \
    DOCKER_HOST=unix:///var/run/docker.sock \
    PATH=$PATH:/app

# Install packages required by the image
RUN apk add --no-cache --virtual .bin-deps \
        bash \
        coreutils \
        curl \
        jq \
        openssl \
        socat

# Install docker-gen from build stage
COPY --from=go-builder /usr/local/bin/docker-gen /usr/local/bin/

# Install acme.sh
COPY /install_acme.sh /app/install_acme.sh
RUN chmod +rx /app/install_acme.sh \
    && sync \
    && /app/install_acme.sh \
    && rm -f /app/install_acme.sh

COPY /app/ /app/

WORKDIR /app

ENTRYPOINT [ "/bin/bash", "/app/entrypoint.sh" ]
CMD [ "/bin/bash", "/app/start.sh" ]
