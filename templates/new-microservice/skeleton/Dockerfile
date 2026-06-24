FROM node:20-alpine
WORKDIR /app
COPY package.json server.js ./
ENV PORT=${{ values.port }}
EXPOSE ${{ values.port }}
CMD ["node", "server.js"]
