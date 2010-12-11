app = module.parent.exports
step = require 'step'
cutil = require '../libs/util'


class Pictures


  # Creates a new Pictures object
  #
  # db: database connection object
  constructor: (db) ->
    @db = db
    @db = app.db


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
        self.db.execute 'SELECT * FROM "Comments" WHERE spam=false AND "album"=? AND "picture"=?', [album, pic], @parallel()
        return undefined
      
      # read picture
      (err, picturerows, albumrows, comments) ->
        if err then throw err
        if not picturerows or picturerows.length is 0 then throw 'Error reading picture ' + album + '/' + pic + ' from database.'

        picture = {}
        for i in [0...picturerows.length]
          if picturerows[i].name is name
            picture = picturerows[i]
            picture.prev = null
            picture.next = null
            if i > 0 then picture.prev = '/pictures/' + album + '/' + picturerows[i - 1].name
            if i < picturerows.length - 1 then picture.next = '/pictures/' + album + '/' + picturerows[i + 1].name

        picture.album = albumrows[0]
        picture.album.url = '/albums/' + album
        picture.url = '/albums/' + album + '/' + picture.name
        picture.thumbnail = '/thumbs/' + album + '/' + picture.name
        picture.comments = comments
 
        callback err, picture
    )


module.exports = Pictures

