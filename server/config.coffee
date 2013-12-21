@IS_LOCAL = (process.env.NODE_ENV in [ 'development', 'test' ])
@SECRET_KEY = (process.env.SECRET_KEY || 'v secure imo')
