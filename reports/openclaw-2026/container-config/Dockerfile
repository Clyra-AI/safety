FROM node:22-bookworm-slim

ARG GO_VERSION=1.25.7

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    procps \
    python3 \
    python3-pip \
  && rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" \
  && case "${arch}" in \
      amd64) go_arch='amd64' ;; \
      arm64) go_arch='arm64' ;; \
      *) echo "unsupported arch: ${arch}" >&2; exit 1 ;; \
     esac \
  && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tgz \
  && rm -rf /usr/local/go \
  && tar -C /usr/local -xzf /tmp/go.tgz \
  && rm /tmp/go.tgz

ENV PATH="/usr/local/go/bin:${PATH}"

RUN corepack enable && corepack prepare pnpm@10.8.0 --activate

WORKDIR /workspace
CMD ["bash"]
