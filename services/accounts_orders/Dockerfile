# Single image, three roles (migrations / API / notification worker) selected by command override
# in docker-compose.yml — same shape as services/catalog_monitor/Dockerfile,
# minus the Playwright runtime this service has no use for.
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY src/db/migrations ./dist/db/migrations

ENV PORT=8082

EXPOSE 8082

CMD ["node", "dist/api/server.js"]
