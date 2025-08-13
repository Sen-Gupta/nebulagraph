# syntax=docker/dockerfile:1

# Build arguments for metadata injection
ARG BUILDTIME
ARG VERSION
ARG REVISION

# Build stage
FROM golang:1.24.5-alpine AS builder

WORKDIR /app

# Install git for version info
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the component with version info
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s -X main.version=${VERSION:-dev} -X main.commit=${REVISION:-unknown} -X main.date=${BUILDTIME:-unknown}" \
    -o /nebula_dapr_pluggable .

# Runtime stage
FROM gcr.io/distroless/static-debian11:latest

# Re-declare build arguments for use in labels
ARG BUILDTIME
ARG VERSION
ARG REVISION

# Add metadata labels
LABEL org.opencontainers.image.title="Dapr Pluggable Component"
LABEL org.opencontainers.image.description="Multi-backend Dapr state store component supporting NebulaGraph and ScyllaDB"
LABEL org.opencontainers.image.vendor="Experiom"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/foodinvitesadmin/dapr-pluggables"
LABEL org.opencontainers.image.source="https://github.com/Sen-Gupta/nebulagraph"
LABEL org.opencontainers.image.documentation="https://github.com/Sen-Gupta/nebulagraph/blob/main/README.md"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${REVISION}"
LABEL org.opencontainers.image.created="${BUILDTIME}"

WORKDIR /

# Copy the binary from build stage
COPY --from=builder /nebula_dapr_pluggable /nebula_dapr_pluggable

# Note: Running as root is required for Dapr pluggable components
# to create Unix sockets in /var/run/

ENTRYPOINT ["/nebula_dapr_pluggable"]
