FROM python:3-alpine AS base

RUN addgroup -S app --gid 1000 && adduser -S app --uid 1000 -G app \
  && mkdir /app \
  && chown app:app /app

RUN apk add --update npm curl jq \
  && npm install pm2 -g

ENV PATH="${PATH}:/home/app/.local/bin"

USER app
WORKDIR /app

FROM base

COPY --chown=app:app ./.env ./twitchToYoutube.sh ./process.yaml refreshToken.sh scheduleLatestVideo.sh youtubeTokenCheck.sh /app/
COPY --chown=app:app ./auth/ /app/auth/

RUN pm2 install pm2-health \
    && pip install --user -U streamlink
RUN mkdir youtubeuploader && wget -c https://github.com/porjo/youtubeuploader/releases/download/23.02/youtubeuploader_23.02_Linux_x86_64.tar.gz -O - | tar -xz -C ./youtubeuploader

COPY --chown=app:app ./pm2_module_conf.json /home/app/.pm2/module_conf.json

CMD pm2 start process.yaml --no-daemon
