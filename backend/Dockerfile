# Stage 1: Build Go Binary
FROM golang:alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Stage 2: Minimal Production Image
FROM alpine:latest

WORKDIR /app

# Copy compiled binary from builder
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]