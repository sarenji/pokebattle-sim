require('coffee-script/register');

process.env.NODE_ENV = process.env.NODE_ENV || "development";

switch (process.env.POKEBATTLE_ENV) {
  case "api":
    var PORT = process.env.PORT || 8082;
    require('./api').createServer(PORT);
    break;
  case "sim":
  default:
    var PORT = process.env.PORT || 8000;
    require('./server').createServer(PORT);
    require('./server/schedule').createScheduler();
    break;
}
