# pokebattle-sim [![Build Status](https://secure.travis-ci.org/sarenji/pokebattle-sim.png?branch=master)](http://travis-ci.org/sarenji/pokebattle-sim)

A competitive Pokemon battle simulator playable in the browser.

## Set up

### Installation

```bash
git clone git://github.com/sarenji/pokebattle-sim.git
cd pokebattle-sim
npm install
```

### Redis

You also need to install redis. On Mac OS X with homebrew, you can do:

```bash
brew install redis
```

On Windows, there is a Redis port that works fairly well: https://github.com/rgl/redis/downloads

## Run server

We use [Grunt](http://gruntjs.com/) to handle our development. First, you must `npm install -g grunt-cli` to get the grunt runner. Then you can type

```bash
grunt
```

to automatically compile all client-side files and run nodemon for you.

### Vagrant (Windows-only, optional)

In case the Windows redis-server does not work for you, we do provide Vagrant. First, you must install 
[Vagrant](http://www.vagrantup.com/) and 
[VirtualBox](https://www.virtualbox.org/wiki/Downloads). Next, run this in the 
terminal, inside the project directory:

```bash
vagrant up
# a whole bunch of stuff
vagrant ssh
cd /vagrant
grunt
```

From there, everything is as normal. To destroy the Vagrant VM when you're 
done:

```bash
vagrant destroy
```

## Run tests

```bash
npm test
```

Or if you're in the Vagrant VM, you can just run

```bash
mocha
```

## Guide

pokebattle-sim is a one-page app. The server serves the client.

```
api/             Hosts the code for the API that we host.
client/          Main client code. Contains JS and CSS.
config/          For Capistrano and deployment.
public/          Public-facing dir. Generated files, fonts, images.
scrapers/        Python scripts; turns Veekun's Pokedex into raw data.
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
