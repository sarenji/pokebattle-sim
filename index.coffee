module.exports = {
  server: if process.env.NUGGETBRIDGE_COV
      require './server-cov'
    else
      require './server'
}
