FROM n8nio/n8n:latest

# Switch to root to install packages
USER root

# Install required tools
RUN apk add --no-cache bash curl

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Switch back to node user
USER node

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]