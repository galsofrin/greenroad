# Stage 1: Build/Dependency stage
FROM node:22-alpine AS builder

WORKDIR /app

# Copy only files needed for installation
COPY package*.json ./

# Install all dependencies (or use --only=production)
RUN npm ci --only=production

# Stage 2: Final Runtime stage
FROM node:22-alpine

WORKDIR /app

# Copy only the necessary files from the builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY server.js ./

EXPOSE 3000

# Set user to non-root for security
USER node

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "server.js"]

