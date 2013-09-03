# battle tower [![Build Status](https://secure.travis-ci.org/sarenji/battletower.png?branch=master)](http://travis-ci.org/sarenji/battletower)

A competitive Pokemon battle simulator playable in the browser.

## Set up

```bash
git clone git://github.com/sarenji/battletower.git
cd battletower
npm install
```

You also need to install redis. On Mac OS X with homebrew, you can do:

```bash
brew install redis
```

## Run server

We use [Grunt](http://gruntjs.com/) to handle our development. First, you must `npm install -g grunt-cli` to get the grunt runner. Then you can type

```bash
grunt
```

to automatically compile all client-side files and run nodemon for you.

### Vagrant

In case you are using Windows or wish to ensure that your development 
environment is consistent, you can use Vagrant. First, you must install 
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

## Guide

battletower is a one-page app. The server serves the client.

```
assets/          Main client code. Contains JS and CSS.
data/            Convert raw data into move/pokemon/etc instances.
scrapers/        Python scripts; turns Veekun's Pokedex into raw data.
server/          Battle logic, move logic, Pokemon logic, etc.
test/            Automated tests for server and client.
views/           All views that are rendered server-side go here.
app.coffee       The main entry point of battletower.
                 The API and socket.io listeners are hosted here. This will probably change.
```

## Contributing

All contributions to the simulator logic must come with tests. If a
contribution does not come with a test that fails before your contribution and
passes after, your contribution will be rejected.

Other contributions (e.g. to the client) are much less strict!

## Issues

Report issues in GitHub's [issue
tracker](https://github.com/sarenji/battletower/issues).
