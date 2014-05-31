process.env.NODE_ENV = process.env.NODE_ENV || "development";

switch (process.env.POKEBATTLE_ENV) {
  case "api":
    var PORT = process.env.PORT || 8082;
    require('coffee-script/register');
    require('./api').createServer(PORT);
    break;
  case "sim":
  default:
    if (process.env.NODE_ENV === 'production') {
      require('nodetime').profile(require('./nodetime.json'));
    }

    var PORT = process.env.PORT || 8000;
    require('coffee-script/register');
    require('./server').createServer(PORT);
    require('./server/schedule').createScheduler();
    break;
}
