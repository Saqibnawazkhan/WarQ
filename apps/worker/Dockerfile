# Warq worker — built from the monorepo root so the shared packages come along.
# Build:  docker build -f apps/worker/Dockerfile -t warq-worker .
FROM node:22-alpine AS build

WORKDIR /app

# Manifests first, so a dependency install is cached across source-only changes.
COPY package.json package-lock.json turbo.json tsconfig.base.json ./
COPY packages/core/package.json packages/core/
COPY packages/tokens/package.json packages/tokens/
COPY apps/worker/package.json apps/worker/

RUN npm ci

COPY packages/ packages/
COPY apps/worker/ apps/worker/

RUN npx turbo run build --filter=@warq/worker...

# Drop dev dependencies from the layer that ships.
RUN npm prune --omit=dev


FROM node:22-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /app

# Run unprivileged.
USER node

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/package.json ./package.json
COPY --from=build --chown=node:node /app/packages ./packages
COPY --from=build --chown=node:node /app/apps/worker ./apps/worker

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "apps/worker/dist/server.js"]
