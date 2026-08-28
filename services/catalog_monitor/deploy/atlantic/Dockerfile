# Lightweight production image for the shared 4 GB Texas host.
# Static HTML/JSON-LD extraction is the only enabled mode here. This image is
# deliberately not based on the Playwright image and removes the optional
# browser packages from the runtime layer.
FROM node:22-slim AS build

WORKDIR /app
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-slim AS runtime

ENV NODE_ENV=production
ENV PORT=8081
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts \
    && rm -rf node_modules/playwright node_modules/playwright-core \
    && npm cache clean --force

COPY --from=build /app/dist ./dist
COPY src/db/migrations ./dist/db/migrations

# The compose file intentionally does not publish this port; Caddy is the
# only ingress path.
CMD ["node", "dist/api/server.js"]
