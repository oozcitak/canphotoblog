path = require 'path'
fs = require 'fs'
step = require 'step'
sqlite = require 'sqlite'
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


  # Starts watching the uploads folder
  start: () ->
    @stopWatching = false
    setTimeout @watchUploads(), @watchInterval
    util.log 'Upload monitor started.'


  # Stops watching the uploads folder
  stop: () ->
    @stopWatching = true
    util.log 'Upload monitor stopped.'

  # Watches the uploads folder for new pictures
  watchUploads: () ->

    self = @
    if self.readingAlbums and not self.stopWatching
      setTimeout self.watchUploads(), self.watchInterval
      return
    self.readingAlbums = true
    albums = []

    step(

      # get albums
      () ->
        self.readUploads @
        return undefined

      # save albums
      (err, newalbums) ->
        if err then throw err
        albums = newalbums

        albumSQL = 'INSERT INTO "Albums" ("name", "dateCreated") VALUES (?, ?)'
        pictureSQL = 'INSERT INTO "Pictures" ("name", "dateTaken", "album") VALUES (?, ?, ?)'

        group = @group()
        for album in albums
          self.db.execute albumSQL, [album.name, cutil.dateToSQLite(album.dateCreated)], group()

          for picture in album.pictures
            self.db.execute pictureSQL, [picture.name, cutil.dateToSQLite(picture.dateTaken), album.name], group()

        return undefined

      # move albums
      (err) ->
        if err then throw err
        
        group = @group()
        for album in albums
          fs.rename path.join(self.uploadDir, album.name), path.join(self.albumDir, album.name), group()
        return undefined
        
      # done
      (err) ->
        if err then throw err
        self.readingAlbums = false
        if not self.stopWatching
          setTimeout self.watchUploads(), self.watchInterval
    )


  # Reads and returns albums from the filesystem
  #
  # callback: err, array of album objects
  readUploads: (callback) ->

    callback = cutil.ensureCallback callback
    self = @
    root = @uploadDir

    step(

      # read directories
      () ->
        fs.readdir root, @
        return undefined

      # build albums
      (err, dirNames) ->
        if err then throw err
        if dirNames? and dirNames.length is 0 then return []
        group = @group()
        for dirName in dirNames
          dir = path.join root, dirName
          if fs.statSync(dir).isDirectory()
            self.readAlbumFromFS dir, group()
        return undefined

      # return albums
      (err, albums) ->
        if err then throw err
        callback err, albums
    )


  # Reads and returns an album from the filesystem
  #
  # root: path to album directory
  # callback: err, album object
  readAlbumFromFS: (root, callback) ->

    callback = cutil.ensureCallback callback
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

        albumName = path.basename root
        pics = []
        for fileName in fileNames
          file = path.join root, fileName
          if fs.statSync(file).isFile()
            pic = {
              name: fileName
            }
            pics.push pic

        album = {
          name: albumName
          pictures: pics
          dateCreated: new Date()
        }

        # create thumbnails
        im.makeAllThumbnails root, path.join(self.thumbDir, album.name), self.thumbSize, @
        return undefined

      # read date taken
      (err) ->
        if err then throw err
        group = @group()
        for pic in album.pictures
          im.getDate path.join(root, pic.name), group()
        return undefined

      # save date taken
      (err, dates) ->
        if err then throw err
        if not dates or dates.length isnt album.pictures.length then throw 'Error reading album ' + album.name + ' from file system.'

        for i in [0...dates.length]
          album.pictures[i].dateTaken = dates[i]

        callback err, album
    )


module.exports = UploadMonitor

