## Setup
### Env variables
Create `.env`
```shell
cp .env-example .env
```
Set your variables in `.env` file

### Twitch token

1) Get Twitch token and get token
https://streamlink.github.io/cli/plugins/twitch.html#authentication

2) Copy `config.twitch-example` into `config.twitch`
```shell
cp ./auth/config.twitch-example ./auth/config.twitch
```
3) Replace `paste_token_here` in `config.twitch` with your token

### YouTube token

Create new project in Google Developers Console, get secrets and save it to `./auth/yt_secrets.json` file
- tutorial here: https://github.com/porjo/youtubeuploader#youtube-api

Run this script and visit the URL it outputs
```shell
docker-compose run -p 8080:8080 app /bin/sh -c "./youtubeuploader/youtubeuploader -secrets ./auth/yt_secrets.json -filename ./process.yaml"
```
After following the link you should have `./auth/request.token` file with access token for YouTube

## Monitoring
Add your SMTP config into `pm2_module_conf.json` if you want email notifications when something fails
- https://github.com/pankleks/pm2-health#readme

## Usage
```shell
docker-compose up -d --build
```

### Logs
```shell
docker-compose logs app
```