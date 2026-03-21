FROM oven/bun:1.2.22-alpine AS builder

WORKDIR /app

ARG VITE_DRUPAL_BASE_URL
ARG VITE_DRUPAL_API_PREFIX
ENV VITE_DRUPAL_BASE_URL=${VITE_DRUPAL_BASE_URL}
ENV VITE_DRUPAL_API_PREFIX=${VITE_DRUPAL_API_PREFIX}

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .
RUN bun run build

FROM nginx:1.27-alpine AS runtime

WORKDIR /usr/share/nginx/html
COPY --from=builder /app/dist ./

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
