app = module.parent.exports
step = require 'step'
path = require 'path'
util = require 'util'
cutil = require '../libs/util'


class Pictures


  # Creates a new Pictures object
  #
  # db: database connection object
  constructor: (db) ->
    @db = db


  # Gets the picture with the given name
  #
  # album: album name
  # pic: picture name
  # callback: err, picture object
  getPicture: (album, pic, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get picture
      () ->
        self.db.execute 'SELECT * FROM "Pictures" WHERE "album"=? ORDER BY "dateTaken" ASC', [album], @parallel()
        self.db.execute 'SELECT * FROM "Albums" WHERE "name"=? LIMIT 1', [album], @parallel()
        self.db.execute 'SELECT * FROM "Comments" WHERE "spam"=0 AND "album"=? AND "picture"=?', [album, pic], @parallel()
        return undefined
      
      # read picture
      (err, picturerows, albumrows, comments) ->
        if err then throw err
        if not picturerows or picturerows.length is 0 then throw new Error('Error reading picture ' + album + '/' + pic + ' from database.')

        picture = {}
        for i in [0...picturerows.length]
          if picturerows[i].name is pic
            picture = picturerows[i]
            picture.album = albumrows[0]
            picture.album.url = '/albums/' + album
            picture.url = '/pictures/' + album + '/' + picture.name
            picture.src = '/albums/' + album + '/' + picture.name
            picture.thumbnail = self.thumbURL album, picture.name
            picture.displayName = picture.title or picture.name
            picture.comments = comments
 
            if i > 0
              picture.prev = picturerows[i - 1]
              picture.prev.url = '/pictures/' + album + '/' + picture.prev.name
              picture.prev.src = '/albums/' + album + '/' + picture.prev.name
              picture.prev.thumbnail = self.thumbURL album, picture.prev.name
              picture.prev.displayName = picture.prev.title or picture.prev.name
            else
              picture.prev = null

            if i < picturerows.length - 1
              picture.next = picturerows[i + 1]
              picture.next.url = '/pictures/' + album + '/' + picture.next.name
              picture.next.src = '/albums/' + album + '/' + picture.next.name
              picture.next.thumbnail = self.thumbURL album, picture.next.name
              picture.next.displayName = picture.next.title or picture.next.name
            else
              picture.next = null

        callback err, picture
    )


  # Gets a random picture
  #
  # callback: err, picture object
  getRandomPicture: (callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get picture
      () ->
        self.db.execute 'SELECT "name", "album" FROM "Pictures" ORDER BY RANDOM() LIMIT 1', @
        return undefined
      
      # read picture
      (err, rows) ->
        self.getPicture rows[0].album, rows[0].name, @
        return undefined
 
      # execute callback
      (err, picture) ->
        if err then throw err
        callback err, picture
    )


  # Edits picture details
  #
  # album: album name
  # pic: picture name
  # title: picture title
  # text: picture text
  # callback: err
  editPicture: (album, pic, title, text, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # edit picture
      () ->
        self.db.execute 'UPDATE "Pictures" SET "title"=?, "text"=? WHERE "album"=? AND "name"=?', [title, text, album, pic], @
        return undefined
      
      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Gets the thumbnail URL for the given picture
  thumbURL: (album, pic) ->
    return '/thumbs/' + album + '/' + path.basename(pic, path.extname(pic)) + '.png'


module.exports = Pictures

