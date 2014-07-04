var connection = {};

if (process.env.DATABASE_URL) {
  var url = require('url').parse(process.env.DATABASE_URL);
  connection.host = url.host;
  connection.database = decodeURI(url.pathname.slice(1));
  connection.user = url.auth[0];
  connection.password = url.auth[1];
} else {
  connection.host = process.env.APP_DB_HOST;
  connection.user = process.env.APP_DB_USER;
  connection.password = process.env.APP_DB_PASSWORD;
  connection.database = process.env.APP_DB_NAME;
}

module.exports = {
  directory: './migrations',
  tableName: 'migrations',
  extension: 'coffee',
  database: {
    client: 'postgresql',
    connection: {
      host     : connection.host     || '127.0.0.1',
      user     : connection.user     || 'postgres',
      password : connection.password || '',
      database : connection.database || 'pokebattle_sim'
    }
  }
}
