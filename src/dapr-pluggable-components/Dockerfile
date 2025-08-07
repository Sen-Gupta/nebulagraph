# syntax=docker/dockerfile:1

# Build
FROM golang:latest AS build

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the component
RUN CGO_ENABLED=0 go build -o /nebula_dapr_pluggable .

# Deploy
FROM gcr.io/distroless/static-debian11

WORKDIR /

# Copy the binary from build stage
COPY --from=build /nebula_dapr_pluggable /nebula_dapr_pluggable

ENTRYPOINT ["/nebula_dapr_pluggable"]
