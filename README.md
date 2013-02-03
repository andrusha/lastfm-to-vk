## Goodies

This app is based on:

* Sinatra
* Sidekiq
* Foundation SCSS
* HAML

## Requirements

* Ruby 1.9
* Redis

## Installation

Currently it is deployed to Heroku instance and is designed in the way
so it can run both web-server and job-queue on the same dyno.

Before starting it you're supposed to set following environment constants:

* `SIDEKIQ_USER`
* `SIDEKIQ_PASS`
* `VK_API_KEY`
* `VK_API_SECRET`
* `REDIS_PROVIDER`

### Running app as developer

* `redis-server`
* `shotgun --server=thin --port 8080 config.ru`
* `sidekiq -r ./app/jobs.rb`
