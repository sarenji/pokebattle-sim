# battle tower

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

battletower is a one-page app, and the server serves the client. Following this
sentence is the main parts that make up battletower with a short explanation of
each.

### assets/

All JavaScript and CSS in this directory are compiled and served to the client.
This is where the main client code lives.

### data/

All raw data goes here. This is also the place that converts raw data into
Move, Pokemon, or other instances for use by the simulator.

### scrapers/

Python scripts to scrape Veekun's Pokedex and populate raw data.

### server/

The entire server logic is encapsulated in this folder.

### test/

Tests for the server and client go here.

### views/

All views that are rendered server-side go here. Since battletower is a single
page app, there likely will only be one view.

### app.coffee

The main entry point of battletower.

The API and socket.io listeners are hosted here. This will probably change.

## Contributing

All contributions to the simulator logic must come with tests. If a
contribution does not come with a test that fails before your contribution and
passes after, your contribution will be rejected.

## Issues

Report issues in GitHub's [issue
tracker](https://github.com/sarenji/battletower/issues).
