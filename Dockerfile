FROM python:3-alpine AS base

RUN addgroup -S app --gid 1000 && adduser -S app --uid 1000 -G app \
  && mkdir /app \
  && chown app:app /app

RUN apk add --update curl jq logrotate \
    && pip install python-dotenv supervisor

COPY supervisord.conf /etc/supervisord.conf
COPY logrotate /etc/logrotate.d/app

ENV PATH="${PATH}:/home/app/.local/bin"

CMD ["supervisord", "-c", "/etc/supervisord.conf"]

USER app
WORKDIR /app

FROM base

COPY --chown=app:app . /app/

RUN pip install --user -U streamlink
RUN mkdir youtubeuploader \
    && wget -c https://github.com/porjo/youtubeuploader/releases/download/23.03/youtubeuploader_23.03_Linux_x86_64.tar.gz -O - | tar -xz -C ./youtubeuploader