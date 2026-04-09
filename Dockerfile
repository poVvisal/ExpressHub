FROM node:18-alpine

WORKDIR /app

# Install dependencies first (layer-cache friendly)
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source
COPY index.js       ./
COPY backend/       ./backend/
COPY frontend/      ./frontend/

EXPOSE 3000

CMD ["node", "index.js"]