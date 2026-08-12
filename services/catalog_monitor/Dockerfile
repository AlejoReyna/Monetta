# Single image, three roles (migrations / API / scheduled monitor) selected
# by command override in docker-compose.yml — see docker-compose.yml and
# README.md § "Container roles".
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# The runtime stage is pinned to the exact Playwright version resolved in
# package-lock.json (see the `playwright` entry) via the matching official
# Playwright image tag, so the Chromium build baked into the image is always
# the one the `playwright` npm package at that version expects — no
# `playwright install` step, no version drift between "what we depend on"
# and "what browser binary is actually on disk." If `npm run build` /
# `package-lock.json` bumps the playwright version, this tag must move with
# it.
FROM mcr.microsoft.com/playwright:v1.62.1-noble AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
# --ignore-scripts: this base image already has the matching Chromium build
# and its system libraries preinstalled, so playwright's own postinstall
# browser-download step is unnecessary (and would just re-fetch the same
# binary this image already ships).
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY src/db/migrations ./dist/db/migrations

# LIVE_CRAWL_ENABLED and PLAYWRIGHT_FALLBACK_ENABLED default to false in
# config.ts even if unset here — see .env.example. Set them explicitly at
# deploy time, never bake `true` into the image.
ENV PORT=8081

EXPOSE 8081

# Default command runs the API; docker-compose.yml overrides this per
# service (migrate: dist/db/migrate.js, monitor: dist/monitor/scheduler.js).
CMD ["node", "dist/api/server.js"]
