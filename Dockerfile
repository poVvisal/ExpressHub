# Use a more specific and recent version of the node:18-alpine image
FROM alpine:latest

WORKDIR /app

# Install nodejs and npm
RUN apk add --no-cache nodejs npm

# Create a dedicated user and group for the application
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Install dependencies first (layer-cache friendly)
COPY --chown=appuser:appgroup package*.json ./
RUN npm install --omit=dev 

# Copy application source
COPY --chown=appuser:appgroup index.js       ./
COPY --chown=appuser:appgroup backend/       ./backend/
COPY --chown=appuser:appgroup frontend/      ./frontend/

# Switch to the non-root user
USER appuser

EXPOSE 5000

CMD ["node", "index.js"]