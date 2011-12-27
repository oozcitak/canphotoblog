path = require 'path'
fs = require 'fs'
step = require 'step'
sqlite = require 'sqlite3'
util = require 'util'
cutil = require './util'
im = require './img'


class UploadMonitor


  # Creates a new upload monitor
  #
  # db: database connection object
  # albumDir: path to album directory
  # thumbDir: path to thumbnail directory
  # uploadDir: path to uploads directory
  # thumbSize: size of generated thumbnails
  # watchInterval: time in milliseconds between new album checks
  constructor: (db, albumDir, thumbDir, uploadDir, thumbSize, watchInterval) ->
    @db = db
    @albumDir = albumDir
    @thumbDir =  thumbDir
    @uploadDir =  uploadDir
    @thumbSize = thumbSize
    @watchInterval = watchInterval
    @workPerStep = 10
    @timer = null


  # Starts watching the uploads folder
  start: () ->
    self = @
    util.log 'Upload monitor starting.'
    self.timer = setInterval () ->
        self.processUploads()
      , self.watchInterval


  # Stops watching the uploads folder
  stop: () ->
    if @timer then clearInterval @timer
    timer = null
    util.log 'Upload monitor stopped.'


  # Restarts the upload monitor
  restart: () ->
    @stop()
    @start()


  # Processes the pictures in the uploads folder
  processUploads: () ->

    self = @
    if self.readingAlbums then return
    self.readingAlbums = true
    albums = []
    pictures = []

    step(

      # get list of pictures
      () ->
        self.readAllPictures @
        return undefined

      # save albums into db
      (err, uploads) ->
        if err then throw err
        pictures = uploads
        if pictures.length is 0 then return null
 
        # dest paths
        for i in [0...pictures.length]
          pictures[i].dest = path.join self.albumDir, pictures[i].album, pictures[i].name

        # make albums
        albums = []
        for pic in pictures
          if pic.album not in albums
            albums.push pic.album

        # save to database
        albumSQL = 'INSERT INTO "Albums" ("name", "dateCreated") 
            SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM "Albums" WHERE "name"=?)'
        pictureSQL = 'INSERT INTO "Pictures" ("name", "dateTaken", "album") 
            SELECT ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM "Pictures" WHERE "name"=? AND "album"=?)'

        group = @group()
        for album in albums
          self.db.run albumSQL, [album, cutil.dateToSQLite(), album], group()
        for pic in pictures
          picdate = ''
          if pic.dateTaken
            picdate = cutil.dateToSQLite(pic.dateTaken)
          else if pic.dateModified
            picdate = cutil.dateToSQLite(pic.dateModified)
          self.db.rub pictureSQL, [pic.name, picdate, pic.album, pic.name, pic.album], group()

        return undefined

      # check album directories
      (err) ->
        if err then throw err
        if albums.length is 0 then return []
        group = @group()
        for album in albums
          cutil.fileExists path.join(self.albumDir, album), group()
        return undefined

      # make album directories
      (err, exists) ->
        if err then throw err
        if exists.length is 0 then return null
        group = @group()
        madedir = false
        for i in [0...albums.length]
          if not exists[i]
            fs.mkdir path.join(self.albumDir, albums[i]), 0755, group()
            madedir = true
        if not madedir then return null
        return undefined

      # check thumb directories
      (err) ->
        if err then throw err
        if albums.length is 0 then return []
        group = @group()
        for album in albums
          cutil.fileExists path.join(self.thumbDir, album), group()
        return undefined

      # make thumb directories
      (err, exists) ->
        if err then throw err
        if exists.length is 0 then return null
        group = @group()
        madedir = false
        for i in [0...albums.length]
          if not exists[i]
            fs.mkdir path.join(self.thumbDir, albums[i]), 0755, group()
            madedir = true
        if not madedir then return null
        return undefined

      # make thumbnails
      (err) ->
        if err then throw err
        if pictures.length is 0 then return []
        group = @group()
        for pic in pictures
          src = pic.source
          ext = path.extname pic.name
          dst = path.join(self.thumbDir, pic.album, path.basename(pic.name, ext) + '.png')
          im.makeThumbnail src, dst, self.thumbSize, group()
        return undefined

      # move pictures
      (err) ->
        if err then throw err
        if pictures.length is 0 then return null
        group = @group()
        for picture in pictures
          fs.rename picture.source, picture.dest, group()
        return undefined
       
      # delete upload folders
      (err) ->
        if err then throw err
        if pictures.length is 0 then return null
        group = @group()
        for album in albums
          fs.rmdir path.join(self.uploadDir, album), group()
        return undefined

      # done
      (err) ->
        if err then throw err
        self.readingAlbums = false
        if pictures.length isnt 0
          util.log 'Read ' + pictures.length + ' new pictures from uploads.'
    )


  # Reads all pictures in the upload folder
  #
  # callback: err, array of picture objects
  readAllPictures: (callback) ->

    callback = cutil.ensureCallback callback
    self = @
    root = @uploadDir
    pictures = []

    step(

      # read files
      () ->
        # read images in root
        self.readPictures root, @parallel()
        # read sub directories
        fs.readdir root, @parallel()
        return undefined

      # read pictures in album directories
      (err, rootpics, dirNames) ->
        if err then throw err

        # assign album names to root pictures
        pictures = rootpics
        for i in [0...pictures.length]
          date = pictures[i].dateTaken or pictures[i].dateModified
          pictures[i].album = cutil.dateToSQLite date, false
        
        hasdirs = false
        group = @group()
        for dirName in dirNames
          dir = path.join root, dirName
          if fs.statSync(dir).isDirectory()
            hasdirs = true
            self.readPictures dir, group()
        if not hasdirs then return []
        return undefined

      # assign album names to pictures in album directories
      (err, albums) ->
        if err then throw err

        for pics in albums
          if pics.length isnt 0
            dirName = path.basename(path.dirname(pics[0].source))
            for i in [0...pics.length]
              pics[i].album = dirName
              pictures.push pics[i]

        callback err, pictures

    )


  # Reads pictures in the given folder
  #
  # root: folder to read
  # callback: err, array of picture objects
  readPictures: (root, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    pictures = []

    step(

      # read files
      () ->
        fs.readdir root, @
        return undefined

      # separate images and read exif date taken
      (err, fileNames) ->
        if err then throw err
        group = @group()
        for fileName in fileNames
          file = path.join root, fileName
          stat = fs.statSync file
          if stat.isFile() and path.extname(file).toLowerCase() is '.jpg'
            pictures.push { name: fileName, source: file, dateModified: stat.mtime }
            im.getDate file, group()

        if pictures.length is 0 then return []
        return undefined

      # execute callback
      (err, dates) ->
        if err then throw err
        if not dates or dates.length isnt pictures.length then throw new Error('Error reading picture dates from file system.')
        for i in [0...dates.length]
          if isNaN(dates[i].getTime()) then dates[i] = null
          pictures[i].dateTaken = dates[i]

        callback err, pictures
    )


module.exports = UploadMonitor

