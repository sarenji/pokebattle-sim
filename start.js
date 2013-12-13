require('coffee-script');

switch (process.env.POKEBATTLE_ENV) {
  case "api":
    var PORT = process.env.PORT || 8082;
    require('./api').createServer(PORT);
    break;
  case "sim":
  default:
    require('./app');
    break;
}
