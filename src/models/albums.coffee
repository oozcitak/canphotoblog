step = require 'step'
cutil = require '../libs/util'

class Albums


  # Creates a new Albums object
  #
  # db: database connection object
  constructor: (db) ->
    @db = db


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
        self.db.execute 'SELECT * FROM "Albums" ORDER BY "name" DESC LIMIT ' +
          (page - 1) * count + ',' + count, @
        return undefined

      # read picture count
      (err, rows) ->
        if err then throw err
        albums = rows
        if albums.length is 0 then return []
        group = @group()
        for album in albums
          self.countPictures album.name, group()
        return undefined
 
      # read pictures
      (err, counts) ->
        if err then throw err
        if albums.length isnt counts.length then throw 'Unable to read picture counts.'
        if albums.length is 0 then return []
        group = @group()
        for i in [0...albums.length]
          albums[i].count = counts[i]
          self.getPictures albums[i].name, 1, 1, group()
        return undefined
      
      # execute callback
      (err, pics) ->
        if err then throw err
        if albums.length isnt pics.length then throw 'Unable to read pictures.'
        for i in [0...albums.length]
          albums[i].url = '/albums/' + albums[i].name
          albums[i].thumbnail = '/thumbs/' + albums[i].name + '/' + pics[i][0].name
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
        self.db.execute 'SELECT * FROM "Comments" WHERE "spam"=0 AND "album"=? AND "picture"=null', [name], @parallel()
        self.countPictures name, @parallel()
        self.getPictures name, page, count, @parallel()
        return undefined

      # read album
      (err, rows, comments, count, pics) ->
        if err then throw err
        if not rows or rows.length is 0 then throw 'Error reading album ' + name + ' from database.'
        if not pics then throw 'Unable to read pictures for album ' + name + '.'

        album = rows[0]
        album.comments = comments
        album.count = count
        album.pictures = pics
        album.url = '/albums/' + album.name
        album.thumbnail = '/thumbs/' + album.name + '/' + album.pictures[0].name
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
    pictures = []

    step(

      # get pictures
      () ->
        self.db.execute 'SELECT * FROM "Pictures" WHERE "album"=? ORDER BY "dateTaken" DESC LIMIT ' +
          (page - 1) * count + ',' + count, [name], @
        return undefined
      
      # read pictures
      (err, rows) ->
        if err then throw err
        pictures = []
        for picture in rows
          picture.url = '/pictures/' + name + '/' + picture.name
          picture.thumbnail = '/thumbs/' + name + '/' + picture.name
          pictures.push picture

        callback err, pictures
    )


module.exports = Albums

