step = require 'step'
cutil = require '../libs/util'


class Comments


  # Creates a new comments object
  #
  # db: database connection object
  constructor: (db, akismetClient) ->
    @db = db
    @akismetClient = akismetClient


  # Adds a new comment to an album
  #
  # album: album name
  # name: user name
  # text: comment text
  # req: request object
  # callback: err
  addToAlbum: (album, name, text, req, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    ip = null
    try
      ip = req.headers['x-forwarded-for']
    catch err
      ip = req.connection.remoteAddress
    ref = req.headers.referer

    step(

      # check spam
      () ->
        if not self.akismetClient then return null
        self.akismetClient.checkSpam { comment_author: name, comment_content: text, user_ip: ip, referrer: ref }, @
        return undefined
     
      # save comment
      (err, spam) ->
        if err then throw err
        if not spam? then spam = false
        spam = if spam then 1 else 0
        params = [album, name, text, cutil.dateToSQLite(), spam, ip]
        self.db.execute 'INSERT INTO "Comments" ("album", "from", "text", "dateCommented", "spam", "ip") ' +
          ' VALUES (?, ?, ?, ?, ?, ?)', params, @
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Adds a new comment to a picture
  #
  # album: album name
  # picture: picture name
  # name: user name
  # text: comment text
  # req: request object
  # callback: err
  addToPicture: (album, picture, name, text, req, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    ip = null
    try
      ip = req.headers['x-forwarded-for']
    catch err
      ip = req.connection.remoteAddress
    ref = req.headers.referer

    step(

      # check spam
      () ->
        if not self.akismetClient then return null
        self.akismetClient.checkSpam { comment_author: name, comment_content: text, user_ip: ip, referrer: ref }, @
        return undefined
     
      # save comment
      (err, spam) ->
        if err then throw err
        if not spam? then spam = false
        spam = if spam then 1 else 0
        params = [album, picture, name, text, cutil.dateToSQLite(), spam, ip]
        self.db.execute 'INSERT INTO "Comments" ("album", "picture", "from", "text", "dateCommented", "spam", "ip") ' +
          ' VALUES (?, ?, ?, ?, ?, ?, ?)', params, @
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


module.exports = Comments

