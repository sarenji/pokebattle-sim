connection = {}
if process.env.DATABASE_URL
  url = require('url').parse(process.env.DATABASE_URL)
  connection.host = url.host
  connection.database = decodeURI(url.pathname.slice(1))
  connection.user = url.auth[0]
  connection.password = url.auth[1]
else
  connection.host = process.env.APP_DB_HOST
  connection.user = process.env.APP_DB_USER
  connection.password = process.env.APP_DB_PASSWORD
  connection.database = process.env.APP_DB_NAME

connection.host     ||= '127.0.0.1'
connection.user     ||= 'postgres'
connection.password ||= ''
connection.database ||= 'pokebattle_sim'

module.exports =
  development:
    client: 'postgresql'
    connection: connection
    debug: true
    migrations:
      tableName: 'migrations'

  staging:
    client: 'postgresql'
    connection: connection
    pool:
      min: 2
      max: 10
    migrations:
      tableName: 'migrations'

  production:
    client: 'postgresql'
    connection: connection
    pool:
      min: 2
      max: 10
    migrations:
      tableName: 'migrations'
