# pokebattle-sim [![Build Status](https://secure.travis-ci.org/sarenji/pokebattle-sim.png?branch=master)](http://travis-ci.org/sarenji/pokebattle-sim)

A competitive Pokemon battle simulator playable in the browser.

## Set up

### Installation

```bash
git clone git://github.com/sarenji/pokebattle-sim.git
cd pokebattle-sim
npm install
```

Next, you need to install two dependencies: redis and PostgreSQL 9.1.

### Redis

On Mac OS X with homebrew, you can do:

```bash
brew install redis
```

On Windows, there is a Redis port that works fairly well: https://github.com/rgl/redis/downloads

### PostgreSQL

PostgreSQL has installable versions for every major OS. In particular, for Mac OS X, there is Postgres.app.

When you install PostgreSQL, you should create a database for pokebattle, called `pokebattle_sim`. You can do this two ways:

```bash
# command-line:
$ createdb pokebattle_sim

# or via SQL client:
CREATE DATABASE pokebattle_sim;
```

Next, you must migrate the database. Simply run:

```bash
npm install -g knex
knex migrate:latest
```

If you get an error complaining that the `postgres` role doesn't exist, run this: `createuser -s -r postgres`.

## Run server

We use [Grunt](http://gruntjs.com/) to handle our development. First, you must `npm install -g grunt-cli` to get the grunt runner. Then you can type

```bash
grunt
```

to automatically compile all client-side files and run `nodemon` for you.

We also [support Vagrant](https://github.com/sarenji/pokebattle-sim/wiki/Running-via-Vagrant) if you are on a Windows machine and so desire.

## Run tests

```bash
npm test
# or
npm install -g mocha
mocha
```

Or if you're in the Vagrant VM, you can just run

```bash
mocha
```

## Deployment

First, you must get SSH access to the server. Then, to deploy:

```bash
cap staging deploy
# test on staging
cap production deploy
```

## Guide

pokebattle-sim is a one-page app. The server serves the client.

```
api/             Hosts the code for the API that we host.
client/          Main client code. Contains JS and CSS.
config/          For Capistrano and deployment.
public/          Public-facing dir. Generated files, fonts, images.
server/          Server, battle, move, Pokemon logic, etc.
shared/          Files shared between server and client.
test/            Automated tests for server and client.
views/           All views that are rendered server-side go here.
Gruntfile.coffee Contains all tasks for pokebattle-sim, like compiling.
start.js         The main entry point of pokebattle-sim.
```

## Contributing

All contributions to the simulator logic must come with tests. If a
contribution does not come with a test that fails before your contribution and
passes after, your contribution will be rejected.

Other contributions (e.g. to the client) are much less strict!

## Issues

Report issues in GitHub's [issue
tracker](https://github.com/sarenji/pokebattle-sim/issues).
