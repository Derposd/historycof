FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim
LABEL com.historycoffee=1
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
COPY drizzle ./drizzle
# Каталог для фото (том docker) должен принадлежать пользователю приложения
RUN mkdir -p /data/uploads && chown node:node /data/uploads
USER node
EXPOSE 3000
# Миграции применяются при старте контейнера
CMD ["sh", "-c", "node dist/db/migrate.js && node dist/main.js"]
