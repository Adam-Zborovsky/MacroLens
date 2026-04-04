FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

ENV PORT=8181
ENV NODE_ENV=production

EXPOSE 8181

CMD ["node", "src/server.js"]
