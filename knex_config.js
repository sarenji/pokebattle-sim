module.exports = {
  directory: './migrations',
  tableName: 'migrations',
  extension: 'coffee',
  database: {
    client: 'postgresql',
    connection: {
      host     : process.env.APP_DB_HOST     || '127.0.0.1',
      user     : process.env.APP_DB_USER     || 'postgres',
      password : process.env.APP_DB_PASSWORD || '',
      database : process.env.APP_DB_NAME     || 'pokebattle_sim'
    }
  }
}
