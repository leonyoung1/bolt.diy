# ---------- Build stage ----------
FROM node:20-bookworm-slim AS build
WORKDIR /app

# pnpm
RUN corepack enable && corepack prepare pnpm@9 --activate

# deps first for caching
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

# copy source and build
COPY . .
RUN pnpm build

# ---------- Runtime stage ----------
FROM node:20-bookworm-slim
WORKDIR /app

# wrangler is needed at runtime for `pages dev`
RUN npm i -g wrangler@4

# copy built app + scripts
COPY --from=build /app /app
RUN chmod +x ./bindings.sh || true

# Railway will inject PORT; default helps local `docker run`
ENV PORT=5173
EXPOSE 5173

# IMPORTANT: bind to ${PORT}, not 5173
CMD sh -lc 'bindings=$(./bindings.sh) && wrangler pages dev ./build/client $bindings --ip 0.0.0.0 --port ${PORT} --no-show-interactive-dev-session'
