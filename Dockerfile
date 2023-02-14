FROM node:16-buster-slim

ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

WORKDIR /usr/src/app
COPY package*.json ./

RUN npm install

COPY app.js ./
COPY bin ./bin
COPY public ./public
COPY routes ./routes
COPY views ./views

RUN apt-get update && apt-get install -y \
  tini \
  && rm -rf /var/lib/apt/lists/*

USER node

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD [ "node", "./bin/www" ]