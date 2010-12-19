step = require 'step'
path = require 'path'
util = require 'util'
cutil = require '../libs/util'


class Comments


  # Creates a new comments object
  #
  # db: database connection object
  constructor: (db, akismetClient) ->
    @db = db
    @akismetClient = akismetClient


  # Gets the comment the given id
  #
  # id: comment id
  # callback: err, comment object
  get: (id, callback) ->

    self = @

    step(

      # read comment
      () ->
        self.db.execute 'SELECT * FROM "Comments" WHERE "id"=?', [id], @
        return undefined
 
      #execute callback
      (err, comments) ->
        if err then throw err
        callback err, comments[0]
         
    )


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


  # Gets the count of pictures with comments
  #
  # callback err, count
  countCommentedPictures: (callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      () ->
        self.db.execute 'SELECT COUNT(*) AS "count" FROM "Comments" WHERE "picture" IS NOT NULL AND "spam"=0', @
        return undefined

      (err, rows) ->
        if err then throw err
        callback err, rows[0].count
    )


  # Gets all pictures with comments starting at the given page
  #
  # page: starting page number, one-based
  # count: number of pictures to return
  # callback: err, array of comment objects
  getCommentedPictures: (page, count, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # read comments
      () ->
        self.db.execute 'SELECT * FROM "Comments" WHERE "picture" IS NOT NULL AND "spam"=0 ORDER BY "dateCommented" DESC LIMIT ' +
            (page - 1) * count + ',' + count, @
        return undefined

      # execute callback
      (err, comments) ->
        if err then throw err

        for i in [0...comments.length]
          comments[i].url = '/pictures/' + comments[i].album + '/' + comments[i].picture
          comments[i].thumbnail = self.thumbURL comments[i].album, comments[i].picture
          comments[i].src = '/albums/' + comments[i].album + '/' + comments[i].picture

        callback err, comments
    )


  # Gets the count of spamcomments
  #
  # callback err, count
  countSpamComments: (callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      () ->
        self.db.execute 'SELECT COUNT(*) AS "count" FROM "Comments" WHERE "picture" IS NOT NULL AND "spam"=1', @
        return undefined

      (err, rows) ->
        if err then throw err
        callback err, rows[0].count
    )


  # Gets all pictures with spam comments starting at the given page
  #
  # page: starting page number, one-based
  # count: number of pictures to return
  # callback: err, array of comment objects
  getSpamComments: (page, count, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # read comments
      () ->
        self.db.execute 'SELECT * FROM "Comments" WHERE "picture" IS NOT NULL AND "spam"=1 ORDER BY "dateCommented" DESC LIMIT ' +
            (page - 1) * count + ',' + count, @
        return undefined

      # execute callback
      (err, comments) ->
        if err then throw err

        for i in [0...comments.length]
          comments[i].url = '/pictures/' + comments[i].album + '/' + comments[i].picture
          comments[i].thumbnail = self.thumbURL comments[i].album, comments[i].picture
          comments[i].src = '/albums/' + comments[i].album + '/' + comments[i].picture

        callback err, comments
    )


  # Edits the comment with the given id
  #
  # id: comment id
  # name: comment author
  # text: comment text
  # callback: err
  edit: (id, name, text, callback) ->

    self = @

    step(

      # delete comment
      () ->
        self.db.execute 'UPDATE "Comments" SET "from"=?, "text"=? WHERE "id"=?', [name, text, id], @
        return undefined

      #execute callback
      (err) ->
        if err then throw err
        callback err
         
    )


  # Deletes the comment with the given id
  #
  # id: comment id
  # callback: err
  delete: (id, callback) ->

    self = @

    step(

      # delete comment
      () ->
        self.db.execute 'DELETE FROM "Comments" WHERE "id"=?', [id], @
        return undefined

      #execute callback
      (err) ->
        if err then throw err
        callback err
         
    )


  # Marks the comment with the given id as spam
  #
  # id: comment id
  # callback: err
  markSpam: (id, callback) ->

    self = @

    step(

      # read comment
      () ->
        self.db.execute 'SELECT * FROM "Comments" WHERE "id"=?', [id], @
        return undefined
 
      # send feedback and mark comment
      (err, comments) ->
        if err then throw err
        comment = comments[0]
        group = @group()
        self.db.execute 'UPDATE "Comments" SET "spam"=1 WHERE "id"=?', [id], group()
        if self.akismetClient
          self.akismetClient.submitSpam { comment_author: comment.from, comment_content: comment.text, user_ip: comment.ip }, group()
        return undefined

      #execute callback
      (err) ->
        if err then throw err
        callback err
         
    )


  # Marks the comment with the given id as ham
  #
  # id: comment id
  # callback: err
  markHam: (id, callback) ->

    self = @

    step(

      # read comment
      () ->
        self.db.execute 'SELECT * FROM "Comments" WHERE "id"=?', [id], @
        return undefined
 
      # send feedback and mark comment
      (err, comments) ->
        if err then throw err
        comment = comments[0]
        group = @group()
        self.db.execute 'UPDATE "Comments" SET "spam"=0 WHERE "id"=?', [id], group()
        if self.akismetClient
          self.akismetClient.submitHam { comment_author: comment.from, comment_content: comment.text, user_ip: comment.ip }, group()
        return undefined

      #execute callback
      (err) ->
        if err then throw err
        callback err
         
    )


  # Gets the thumbnail URL for the given picture
  #
  # album: album name
  # pic: picture name
  thumbURL: (album, pic) ->
    return '/thumbs/' + album + '/' + path.basename(pic, path.extname(pic)) + '.png'
 

module.exports = Comments

