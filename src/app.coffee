path = require 'path'
fs = require 'fs'
util = require 'util'
crypto = require 'crypto'
im = require 'imagemagick'
step = require 'step'
sqlite = require 'sqlite'
url = require 'url'

class CanPhotoBlog


  # Creates a new App
  constructor: () ->
    @albumRoot = path.join path.dirname(__dirname), 'public', 'albums'
    @thumbDir =  path.join path.dirname(__dirname), 'public', 'thumbs'
    @dbFile = path.join path.dirname(__dirname), 'album.sqlite'


  # Initializes the application
  init: (callback) ->

    callback = @ensureCallback callback
    dbexists = true
    self = @

    step(
     
      # check database
      () ->
        self.fileExists self.dbFile, @
        return undefined

      # open database
      (err, exists) ->
        if err then throw err
        dbexists = exists
        self.db = new sqlite.Database ()
        self.db.open self.dbFile, @
        return undefined

      # make database if it does not exist
      (err) ->
        if err then throw err
        if dbexists
          return null
        self.makeDatabase @
        return undefined
          
      # read settings
      (err) ->
        if err then throw err
        self.readSettings @
        return undefined

      # check if directories exist
      (err) ->
        if err then throw err
        self.fileExists self.albumRoot, @parallel ()
        self.fileExists self.thumbDir, @parallel ()
        return undefined

      # create directories
      (err, albumsExists, thumbsExists) ->
        if err then throw err
        if albumsExists and thumbsExists then return null
        if not albumsExists then fs.mkdir self.albumRoot, 0755, @parallel ()
        if not thumbsExists then fs.mkdir self.thumbDir, 0755, @parallel ()
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        util.log 'Application initialized. Album root: ' + self.albumRoot
        callback (err)
    )


  # Reads application settings
  readSettings: (callback) ->

    callback = @ensureCallback callback
    self = @

    step(
      
      # read settings
      () ->
        self.db.execute 'SELECT * FROM "Settings"', @
        return undefined
      
      # execute callback
      (err, rows) ->
        if err then throw err
        if not rows then throw 'Unable to read application settings.'

        for item in rows
          switch item.name
            when 'albumsPerPage' then self.albumsPerPage = item.value
            when 'picturesPerPage' then self.picturesPerPage = item.value
            when 'appName' then self.appName = item.value
            when 'appTitle' then self.appTitle = item.value
            when 'thumbSize' then self.thumbSize = item.value

        callback err
    )


  # Creates the album database
  makeDatabase: (callback) ->

    callback = @ensureCallback callback
    self = @

    step(

      # make tables
      () ->

        self.db.executeScript 'DROP TABLE IF EXISTS "Albums";' +
          'DROP TABLE IF EXISTS "Pictures";' +
          'DROP TABLE IF EXISTS "Comments";' +
          'DROP TABLE IF EXISTS "Settings";' +
          'CREATE TABLE "Albums" ("key", "name", "path", "dateTaken");' +
          'CREATE TABLE "Pictures" ("key", "name", "path", "dateTaken", "album");' +
          'CREATE TABLE "Comments" ("key", "from", "text", "dateCommented", "album", "picture");' +
          'CREATE TABLE "Settings" ("name", "value");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("albumsPerPage", "20");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("picturesPerPage", "40");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("appName", "canphotoblog");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("appTitle", "canphotoblog");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("thumbSize", "150");', @

        return undefined

      # execute callback
      (err) ->
        if err then throw err
        util.log 'Created album database.'
        callback err
    )
 

  # Gets the album count
  countAlbums: (callback) ->

    callback = @ensureCallback callback
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
  getAlbums: (page, callback) ->

    callback = @ensureCallback callback
    albums = []
    self = @

    step(

      # read albums
      () ->
        startrow = (page - 1) * self.albumsPerPage
        endrow = self.albumsPerPage
        self.db.execute 'SELECT * FROM "Albums" ORDER BY "dateTaken" DESC LIMIT ' + startrow + ',' + endrow, @
        return undefined

      # read picture count
      (err, rows) ->
        if err then throw err
        albums = rows
        group = @group ()
        for album in albums
          self.countPictures album, group ()
        return undefined
 
      # read pictures
      (err, counts) ->
        if err then throw err
        if albums.length isnt counts.length then throw 'Unable to read picture counts.'
        group = @group ()
        for i in [0...albums.length]
          albums[i].count = counts[i]
          self.getPictures albums[i], 1, group ()
        return undefined
      
      # execute callback
      (err, pics) ->
        if err then throw err
        if albums.length isnt pics.length then throw 'Unable to read pictures.'
        for i in [0...albums.length]
          albums[i].pictures = pics[i]
          albums[i].url = path.join '/albums', albums[i].name
          albums[i].thumbnail = path.join '/thumbs', albums[i].name, albums[i].pictures[0].name
        callback err, albums
    )


  # Gets the album with the given name
  getAlbum: (name, page, callback) ->
    callback = @ensureCallback callback
    key = @makeKey path.join(@albumRoot, name)
    @getAlbumByKey key, page, (err, album) ->
      callback err, album

    
  # Gets the album with the given key
  getAlbumByKey: (key, page, callback) ->

    callback = @ensureCallback callback
    self = @
    album = {}

    step(

      # get album
      () ->
        self.db.execute 'SELECT * FROM "Albums" WHERE "key"=? LIMIT 1', [key], @
        return undefined

      # picture count
      (err, rows) ->
        if err then throw err
        if not rows then throw 'Error reading album ' + key + ' from database.'
        album = rows[0]
        self.countPictures album, @
        return undefined
    
      # read pictures
      (err, count) ->
        if err then throw err
        album.count = count
        self.getPictures album, page, @
        return undefined
      
      # execute callback
      (err, pics) ->
        if err then throw err
        if not pics then throw 'Unable to read pictures for album ' + key + '.'
        album.pictures = pics
        album.url = path.join '/albums', album.name
        album.thumbnail = path.join '/thumbs', album.name, album.pictures[0].name
        callback err, album
    )


  # Gets the count of all pictures in the given album
  countPictures: (album, callback) ->

    callback = @ensureCallback callback
    self = @

    step(

      # get pictures
      () ->
        self.db.execute 'SELECT COUNT(*) AS "count" FROM "Pictures" WHERE "album"=?', [album.key], @
        return undefined
      
      # read pictures
      (err, rows) ->
        if err then throw err
        callback err, rows[0].count
    )


  # Reads all pictures for the given album
  getPictures: (album, page, callback) ->

    callback = @ensureCallback callback
    self = @
    pictures = []

    step(

      # get pictures
      () ->
        startrow = (page - 1) * self.picturesPerPage
        endrow = self.picturesPerPage
        self.db.execute 'SELECT * FROM "Pictures" WHERE "album"=? ORDER BY "dateTaken" DESC LIMIT ' + startrow + ',' + endrow, [album.key], @
        return undefined
      
      # read pictures
      (err, rows) ->
        if err then throw err
        pictures = []
        for picture in rows
          picture.url = path.join '/pictures', album.name, picture.name
          picture.thumbnail = path.join '/thumbs', album.name, picture.name
          pictures.push picture

        callback err, pictures
    )

  # Gets the picture with the given name
  getPicture: (album, picture, callback) ->
    callback = @ensureCallback callback
    key = @makeKey path.join(@albumRoot, album, picture)
    @getPictureByKey album, key, (err, pic) ->
      callback err, pic

    
  # Gets the picture with the given key
  getPictureByKey: (album, key, callback) ->

    callback = @ensureCallback callback
    self = @

    step(

      # get picture
      () ->
        albumkey = self.makeKey path.join(self.albumRoot, album)
        self.db.execute 'SELECT * FROM "Pictures" WHERE "album"=?', [albumkey], @parallel ()
        self.db.execute 'SELECT * FROM "Albums" WHERE "key"=?', [albumkey], @parallel ()
        self.db.execute 'SELECT * FROM "Comments" WHERE "album"=? AND "picture"=?', [albumkey, key], @parallel ()
        return undefined
      
      # read picture
      (err, picturerows, albumrows, comments) ->
        if err then throw err

        picture = {}
        for i in [0...picturerows.length]
          if picturerows[i].key is key
            picture = picturerows[i]
            picture.prev = null
            picture.next = null
            if i > 0 then picture.prev = path.join '/pictures', album, picturerows[i - 1].name
            if i < picturerows.length - 1 then picture.next = path.join '/pictures', album, picturerows[i + 1].name

        picture.album = albumrows[0]
        picture.album.url = path.join '/albums', album
        picture.url = path.join '/albums', album, picture.name
        picture.thumbnail = path.join '/thumbs', album, picture.name
        picture.comments = comments
 
        callback err, picture
    )


  # Rebuilds all albums
  rebuildAllAlbums: (callback) ->

    callback = @ensureCallback callback
    self = @

    step(

      # get albums
      () ->
        self.readAlbumsFromFS @
        return undefined

      # save albums
      (err, albums) ->
        if err then throw err

        albumSQL = 'INSERT INTO "Albums" ("key", "name", "path", "dateTaken") VALUES (?, ?, ?, ?)'
        pictureSQL = 'INSERT INTO "Pictures" ("key", "name", "path", "dateTaken", "album") VALUES (?, ?, ?, ?, ?)'

        group = @group ()
        for album in albums
          album.key = self.makeKey album.path
          self.db.execute albumSQL, [album.key, album.name, album.path, album.date], group ()

          for picture in album.pictures
            picture.key = self.makeKey picture.path
            self.db.execute pictureSQL, [picture.key, picture.name, picture.path, picture.date, album.key], group ()

        return undefined

      # execute callback
      (err) ->
        if err then throw err
        util.log 'All albums synced with file system.'
        callback err
    )


  # Returns the MD5 hash of the given album path
  makeKey: (path) ->
    hash = crypto.createHash 'md5'
    hash.update path
    hash.digest 'hex'


  # Reads and returns albums from the filesystem
  readAlbumsFromFS: (callback) ->

    callback = @ensureCallback callback
    self = @
    root = @albumRoot

    step(

      # read directories
      () ->
        fs.readdir root, @
        return undefined

      # build albums
      (err, dirNames) ->
        if err then throw err
        if dirNames? and dirNames.length is 0 then return []
        group = @group ()
        for dirName in dirNames
          dir = path.join root, dirName
          if fs.statSync(dir).isDirectory()
            self.readAlbumFromFS dir, group ()
        return undefined

      # save albums
      (err, albums) ->
        if err then throw err
        util.log 'Read all ' + albums.length + ' albums from: ' + root
        callback err, albums
    )


  # Reads and returns an album from the filesystem
  readAlbumFromFS: (root, callback) ->

    callback = @ensureCallback callback
    self = @
    album = {}

    step(

      # read directory
      () ->
        fs.readdir root, @
        return undefined
        
      # save pictures
      (err, fileNames) ->
        if err then throw err

        pics = []
        for fileName in fileNames
          file = path.join root, fileName
          if fs.statSync(file).isFile()
            pic = {
              path: file
              name: fileName
            }
            pics.push pic

        album = {
          path: root
          name: path.basename(root)
          pictures: pics
        }

        return null

      # read date taken
      (err) ->
        if err then throw err
        fs.stat album.path, @
        return undefined

      # save date taken
      (err, stat) ->
        if err then throw err

        album.date = Math.round(stat.mtime.getTime() / 1000)
        for pic in album.pictures
          pic.date = album.date

        callback err, album
    )


  # Makes a thumbnail image
  makeThumbnail: (album, picture, callback) ->

    callback = @ensureCallback callback
    self = @
    sourceDir = path.join @albumRoot, album
    destDir = path.join @thumbDir, album
    source = path.join sourceDir, picture
    dest = path.join destDir, picture

    step(

      # check if directory exists
      () ->
        self.fileExists destDir, @
        return undefined

      # create if not
      (err, exists) ->
        if err then throw err
        if not exists
          fs.mkdir destDir, 0755, @
          return undefined
        else
          return null

      # check if thumbnail already exists
      (err) ->
        if err then throw err
        self.fileExists dest, @
        return undefined

      # build thumbnail if not
      (err, exists) ->
        if err then throw err
        if exists
          return null
        else
          args = [
              source,
              '-size ' + self.thumbSize + 'x' + self.thumbSize,
              dest
            ]
          im.resize { srcPath: source, dstPath: dest, width: self.thumbSize }, @
          return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err
    )

  # path.exists with err argument
  fileExists: (file, callback) ->
    callback = @ensureCallback callback
    path.exists file, (exists) ->
      callback null, exists


  # Ensures that the callback is valid
  ensureCallback: (callback) ->
    def = () ->
    callback or= def


  # Makes pagination
  makePagination: (uri, pages) ->
    if pages <= 1 then return null

    parts = url.parse uri, true
    if not parts.query?
      parts.query = { page: '1' }
    if not parts.query.page?
      parts.query.page = '1'
    page = parts.query.page
    ipage = parseInt(page)
    pagination = []

    for i in [1...(1 + pages)]
      opage = {}
      opage.text = String(i)
      opage.selected = if String(i) is page then true else false
      opage.islink = !opage.selected
      parts.query.page = String(i)
      opage.url = url.format parts
      pagination.push opage

    return pagination

         
module.exports = new CanPhotoBlog

