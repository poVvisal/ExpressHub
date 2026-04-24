# Use a more specific and recent version of the node:18-alpine image
FROM node:18.20.4-alpine3.20

WORKDIR /app

# Update packages to get security patches
RUN apk add --no-cache --upgrade

# Install dependencies first (layer-cache friendly)
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source
COPY index.js       ./
COPY backend/       ./backend/
COPY frontend/      ./frontend/

EXPOSE 3000

CMD ["node", "index.js"]