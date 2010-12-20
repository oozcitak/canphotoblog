fs = require 'fs'
step = require 'step'
path = require 'path'
cutil = require '../libs/util'

class Albums


  # Creates a new Albums object
  #
  # db: database connection object
  # albumDir: path to album directory
  constructor: (db, albumDir) ->
    @db = db
    @albumDir = albumDir


  # Gets the album count
  #
  # callback err, count
  countAlbums: (callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      () ->
        self.db.execute 'SELECT COUNT(*) AS "count" FROM "Albums"', @
        return undefined

      (err, rows) ->
        if err then throw err
        callback err, rows[0].count
    )


  # Gets all albums starting at the given page
  #
  # page: starting page number, one-based
  # count: number of albums to return
  # callback: err, array of album objects
  getAlbums: (page, count, callback) ->

    callback = cutil.ensureCallback callback
    albums = []
    self = @

    step(

      # read albums
      () ->
        self.db.execute 'SELECT "Albums".*, "Pictures"."name" AS "thumbnail", COUNT("Pictures"."id") AS "count"
            FROM "Albums" LEFT JOIN "Pictures" ON "Albums"."name" = "Pictures"."album"
            GROUP BY "id" ORDER BY "name" DESC LIMIT ' +
            (page - 1) * count + ',' + count, @parallel()
        self.db.execute 'SELECT "album", COUNT("album") AS "count" FROM "Comments"
            WHERE "spam"=0 GROUP BY "album"', @parallel()
            
        return undefined

      # execute callback
      (err, albums, comments) ->
        if err then throw err

        counts = {}
        for comment in comments
          counts[comment.album] = comment.count

        for i in [0...albums.length]
          albums[i].url = '/albums/' + albums[i].name
          albums[i].thumbnail = self.thumbURL albums[i].name, albums[i].thumbnail
          albums[i].comments = counts[albums[i].name] or 0
          albums[i].displayName = albums[i].title or albums[i].name
          albums[i].title or= ""
          albums[i].text or= ""

        callback err, albums
    )


  # Gets the album with the given name
  #
  # name: album name
  # page: starting page number (for pictures), one-based
  # count: number of pictures to return
  # callback: err, album object
  getAlbum: (name, page, count, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    album = {}

    step(

      # get album
      () ->
        self.db.execute 'SELECT * FROM "Albums" WHERE "name"=? LIMIT 1', [name], @parallel()
        self.db.execute 'SELECT * FROM "Comments" WHERE "spam"=0 AND "album"=? AND "picture" IS NULL', [name], @parallel()
        self.countPictures name, @parallel()
        self.getPictures name, page, count, @parallel()
        return undefined

      # read album
      (err, rows, comments, count, pics) ->
        if err then throw err
        if not rows or rows.length is 0 then throw new Error('Error reading album ' + name + ' from database.')
        if not pics then throw new Error('Unable to read pictures for album ' + name + '.')

        album = rows[0]
        album.comments = comments
        album.count = count
        album.pictures = pics
        album.url = '/albums/' + album.name
        album.thumbnail = self.thumbURL album.name, album.pictures[0].name
        album.displayName = album.title or album.name
        album.title or= ""
        album.text or= ""

        callback err, album
    )


  # Gets the count of all pictures in the given album
  #
  # name: album name
  # callback: err, count
  countPictures: (name, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get pictures
      () ->
        self.db.execute 'SELECT COUNT(*) AS "count" FROM "Pictures" WHERE "album"=?', [name], @
        return undefined
      
      # read pictures
      (err, rows) ->
        if err then throw err
        callback err, rows[0].count
    )


  # Gets all pictures for the given album
  #
  # name: album name
  # page: starting page number (for pictures), one-based
  # count: number of pictures to return
  # callback: err, array of picture objects
  getPictures: (name, page, count, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get pictures
      () ->
        self.db.execute 'SELECT * FROM "Pictures" WHERE "album"=? ORDER BY "dateTaken" 
            ASC LIMIT ' + (page - 1) * count + ',' + count, [name], @parallel()
        self.db.execute 'SELECT "picture", COUNT("picture") AS "count" FROM "Comments" WHERE "album"=? 
            AND "spam"=0 AND NOT "picture" IS NULL GROUP BY "picture"', [name], @parallel()
        return undefined

      # read pictures
      (err, pictures, comments) ->
        if err then throw err

        counts = {}
        for comment in comments
          counts[comment.picture] = comment.count

        for i in [0...pictures.length]
          pictures[i].url = '/pictures/' + name + '/' + pictures[i].name
          pictures[i].thumbnail = self.thumbURL name, pictures[i].name
          pictures[i].comments = counts[pictures[i].name] or 0
          pictures[i].displayName = pictures[i].title or pictures[i].name
          pictures[i].title or= ""
          pictures[i].text or= ""

        callback err, pictures
    )


  # Edits album details
  #
  # album: album name
  # title: picture title
  # text: picture text
  # callback: err
  editAlbum: (album, title, text, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # edit album
      () ->
        self.db.execute 'UPDATE "Albums" SET "title"=?, "text"=? WHERE "name"=?', [title, text, album], @
        return undefined
      
      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Deletes an album and all contained pictures
  #
  # album: album name
  # callback: err
  delete: (album, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      #get all pictures
      () ->
        self.db.execute 'SELECT "name" FROM "Pictures" WHERE "album"=?', [album], @
        return undefined

      #delete pictures
      (err, pics) ->
        if err then throw err
        group = @group()
        self.db.execute 'DELETE FROM "Comments" WHERE "album"=?', [album], group()
        self.db.execute 'DELETE FROM "Pictures" WHERE "album"=?', [album], group()
        self.db.execute 'DELETE FROM "Albums" WHERE "name"=?', [album], group()
        for pic in pics
          fs.unlink path.join(self.albumDir, album, pic.name), group()
        return undefined

      # delete album directory
      (err) ->
        if err then throw err
        fs.rmdir path.join(self.albumDir, album), @
        return undefined
      
      # execute callback
      (err) ->
        if err then throw err
        callback err
    )


  # Gets the thumbnail URL for the given picture
  thumbURL: (album, pic) ->
    return '/thumbs/' + album + '/' + path.basename(pic, path.extname(pic)) + '.png'
    

module.exports = Albums

