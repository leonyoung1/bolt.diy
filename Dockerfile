# ---- Build stage ----
FROM node:20-alpine AS build
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@9 --activate
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# ---- Runtime stage ----
FROM node:20-alpine
WORKDIR /app

# 1) Install wrangler (so the CMD can call it)
RUN npm i -g wrangler@4

# 2) Copy the built app and scripts
COPY --from=build /app /app
RUN chmod +x ./bindings.sh || true

# 3) Ports: Railway injects $PORT; default to 5173 for local runs
ENV PORT=5173
EXPOSE 5173

# 4) Start the Pages dev server (the one bolt expects in Docker)
CMD sh -lc 'bindings=$(./bindings.sh) && wrangler pages dev ./build/client $bindings --ip 0.0.0.0 --port ${PORT} --no-show-interactive-dev-session'
