FROM oven/bun:1.2.22-alpine AS builder

WORKDIR /app

ARG OPENRING_VERSION=latest
ARG UMAMI_SITE_ID
ENV PATH="/root/go/bin:${PATH}"

RUN apk add --no-cache go git ca-certificates && \
	go install git.sr.ht/~sircmpwn/openring@${OPENRING_VERSION}

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
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 8380

CMD ["nginx", "-g", "daemon off;"]
