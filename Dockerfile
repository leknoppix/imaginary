FROM cgr.dev/chainguard/go:latest-dev AS builder

ENV GOPATH=/go

ARG IMAGINARY_VERSION=dev

RUN apk upgrade --no-cache --no-interactive \
    && apk add --no-cache --no-interactive ca-certificates jemalloc libvips-dev posix-libc-utils

WORKDIR ${GOPATH}/src/github.com/leknoppix/imaginary


# Cache go modules
ENV GO111MODULE=on

COPY go.mod .
COPY go.sum .

RUN go mod download

# Copy imaginary sources
COPY . .

# Compile imaginary
RUN go build -a \
    -buildmode=pie \
    -o ${GOPATH}/bin/imaginary \
    -ldflags="-s -w -h -X main.Version=${IMAGINARY_VERSION}" \
    -trimpath \
    github.com/leknoppix/imaginary

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

RUN ldd /go/bin/imaginary | tr -s '[:blank:]' '\n' | grep '^/' | \
    xargs -I {} bash -c 'mkdir -p $(dirname deps/{}); cp {} deps/{};' \
    && rm -rf /go/src/github.com/leknoppix/imaginary/deps/lib64 \
    && rm -rf /go/src/github.com/leknoppix/imaginary/deps/lib \
    && rm /go/src/github.com/leknoppix/imaginary/deps/usr/lib/libc.so.* \
    && rm /go/src/github.com/leknoppix/imaginary/deps/usr/lib/libm.so.* \
    && rm /go/src/github.com/leknoppix/imaginary/deps/usr/lib/libgcc_s.so.* \
    && rm /go/src/github.com/leknoppix/imaginary/deps/usr/lib/libstdc++.so.*

FROM cgr.dev/chainguard/glibc-dynamic:latest

ARG IMAGINARY_VERSION

LABEL maintainer="60801403+leknoppix@users.noreply.github.com" \
      org.label-schema.description="Fast, simple, scalable HTTP microservice for high-level image processing with first-class Docker support" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://github.com/leknoppix/imaginary" \
      org.label-schema.vcs-url="https://github.com/leknoppix/imaginary" \
      org.label-schema.version="${IMAGINARY_VERSION}"

COPY --from=builder --chmod=755 /go/bin/imaginary /usr/local/bin/
COPY --from=builder /go/src/github.com/leknoppix/imaginary/deps /

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Server port to listen
ENV PORT=9000

# Drop privileges for non-UID mapped environments
USER nonroot

# Run the entrypoint command by default when the container starts.
ENTRYPOINT ["/usr/local/bin/imaginary"]

# Expose the server TCP port
EXPOSE ${PORT}
