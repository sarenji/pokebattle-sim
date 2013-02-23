# battle tower [![Build Status](https://secure.travis-ci.org/sarenji/battletower.png?branch=master)](http://travis-ci.org/sarenji/battletower)

A competitive Pokemon battle simulator playable in the browser.

## Set up

```bash
git clone git://github.com/sarenji/battletower.git
cd battletower
npm install
```

## Run server

```bash
npm start
```

Or if you have `nodemon`:

```bash
nodemon app.coffee
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

## Issues

Report issues in GitHub's [issue
tracker](https://github.com/sarenji/battletower/issues).
