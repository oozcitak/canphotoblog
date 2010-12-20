fs = require 'fs'
step = require 'step'
path = require 'path'
util = require 'util'
cutil = require '../libs/util'


class Pictures


  # Creates a new Pictures object
  #
  # db: database connection object
  # albumDir: path to album directory
  constructor: (db, albumDir) ->
    @db = db
    @albumDir = albumDir


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
            picture.title or= ""
            picture.text or= ""
 
            if i > 0
              picture.prev = picturerows[i - 1]
              picture.prev.url = '/pictures/' + album + '/' + picture.prev.name
              picture.prev.src = '/albums/' + album + '/' + picture.prev.name
              picture.prev.thumbnail = self.thumbURL album, picture.prev.name
              picture.prev.displayName = picture.prev.title or picture.prev.name
              picture.prev.title or= ""
              picture.prev.text or= ""
            else
              picture.prev = null

            if i < picturerows.length - 1
              picture.next = picturerows[i + 1]
              picture.next.url = '/pictures/' + album + '/' + picture.next.name
              picture.next.src = '/albums/' + album + '/' + picture.next.name
              picture.next.thumbnail = self.thumbURL album, picture.next.name
              picture.next.displayName = picture.next.title or picture.next.name
              picture.next.title or= ""
              picture.next.text or= ""
            else
              picture.next = null

        callback err, picture
    )


  # Gets a random picture
  #
  # callback: err, { name, album } object
  getRandomPicture: (callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get picture
      () ->
        self.db.execute 'SELECT "name", "album" FROM "Pictures" ORDER BY RANDOM() LIMIT 1', @
        return undefined
      
      # return picture
      (err, rows) ->
        if err then throw err
        callback err, rows[0]

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


  # Deletes a picture
  #
  # album: album name
  # pic: picture name
  # callback: err
  delete: (album, pic, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # delete picture
      () ->
        group = @group()
        self.db.execute 'DELETE FROM "Comments" WHERE "album"=? and "picture"=?', [album, pic], group()
        self.db.execute 'DELETE FROM "Pictures" WHERE "album"=? and "name"=?', [album, pic], group()
        fs.unlink path.join(self.albumDir, album, pic), group()
        return undefined
      
      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Moves a picture
  #
  # album: album name
  # pic: picture name
  # target: target album name
  # callback: err
  move: (album, pic, target, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(
    
      # check target dir
      () ->
        cutil.fileExists path.join(self.albumDir, target), @
        return undefined

      # create if not
      (err, exists) ->
        if err then throw err
        if exists
          return null
        else
          fs.mkdir path.join(self.albumDir, target), 0755, @parallel()
          self.db.execute 'INSERT INTO "Albums" ("name", "dateCreated") 
            SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM "Albums" WHERE "name"=?)',
            [album, cutil.dateToSQLite(), album], @parallel()
          return undefined

      # move picture
      (err) ->
        if err then throw err
        group = @group()
        self.db.execute 'UPDATE "Comments" SET "album"=? WHERE "album"=? and "picture"=?', [target, album, pic], group()
        self.db.execute 'UPDATE "Pictures" SET "album"=? WHERE "album"=? and "name"=?', [target, album, pic], group()
        fs.rename path.join(self.albumDir, album, pic), path.join(self.albumDir, target, pic), group()
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

