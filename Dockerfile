# ---------- base (pnpm-enabled) ----------
FROM node:22-bookworm-slim AS base
WORKDIR /app
ENV HUSKY=0 CI=true
# Enable pnpm via corepack
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

# ---------- build ----------
FROM base AS build
# Accept optional public URL for Vite/Remix
ARG VITE_PUBLIC_APP_URL
ENV VITE_PUBLIC_APP_URL=${VITE_PUBLIC_APP_URL}

# Install deps efficiently
COPY package.json pnpm-lock.yaml* ./
RUN pnpm fetch

# Copy source and build
COPY . .
# Install with dev deps to build
RUN pnpm install --offline --frozen-lockfile
# Build (SSR + client)
RUN NODE_OPTIONS=--max-old-space-size=4096 pnpm run build
# Prune to production deps only
RUN pnpm prune --prod --ignore-scripts

# ---------- runtime ----------
FROM node:22-bookworm-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
# Railway provides PORT at runtime; do NOT hardcode it.
ENV HOST=0.0.0.0

# (Optional) curl for healthchecks/logs
RUN apt-get update && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*

# Copy only what the server needs
COPY --from=build /app/build /app/build
COPY --from=build /app/public /app/public
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/package.json /app/package.json

# EXPOSE is metadata; keep 3000 as a sensible default
EXPOSE 3000

# Healthcheck uses the actual runtime port (defaults to 3000 if PORT is unset)
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
  CMD /bin/sh -lc 'curl -fsS "http://127.0.0.1:${PORT:-3000}/" || exit 1'

# Start the Remix server (must listen on process.env.PORT and 0.0.0.0)
CMD ["node", "build/server/index.js"]
