step = require 'step'
cutil = require '../libs/util'


class Comments


  # Creates a new comments object
  #
  # db: database connection object
  constructor: (db, akismetClient) ->
    @db = db
    @akismetClient = akismetClient


  # Adds a new comment
  #
  # album: album name
  # picture: picture name
  # name: user name
  # text: comment text
  # req: request object
  # callback: err
  add: (album, picture, name, text, req, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    ip = null
    try
      ip = req.headers['x-forwarded-for']
    catch err
      ip = req.connection.remoteAddress
    ref = request.headers.referer

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
        self.db.execute 'INSERT INTO "Comments" ("album", "picture", "from", "text", "dateCommented", "spam", "ip") ' +
          ' VALUES (?, ?, ?, ?, datetime("now"), ?, ?)', [album, picture, name, text, spam, ip], @
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


module.exports = Comments

