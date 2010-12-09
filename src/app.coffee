path = require 'path'
fs = require 'fs'
util = require 'util'
step = require 'step'
akismet = require 'akismet'
cutil = require './util'


Database = require './database'
Comments = require './comments'
Albums = require './albums'
Pictures = require './pictures'
UploadMonitor = require './monitor'


class CanPhotoBlog


  # Creates a new App
  constructor: () ->
    @albumDir = path.join path.dirname(__dirname), 'public', 'albums'
    @thumbDir =  path.join path.dirname(__dirname), 'public', 'thumbs'
    @uploadDir =  path.join path.dirname(__dirname), 'uploads'
    @dbFile = path.join path.dirname(__dirname), 'album.sqlite'
    @akismetClient = null


  # Initializes the application
  #
  # callback: err
  init: (callback) ->

    callback = cutil.ensureCallback callback
    dbexists = true
    self = @

    step(
     
      # open database
      () ->
        db = new Database (self.dbFile)
        db.init @
        return undefined

      # check if directories exist
      (err, db, settings) ->
        if err then throw err
        self.db = db
        self.settings = settings

        cutil.fileExists self.albumDir, @parallel ()
        cutil.fileExists self.thumbDir, @parallel ()
        cutil.fileExists self.uploadDir, @parallel ()
        return undefined

      # create directories
      (err, albumsExists, thumbsExists, uploadsExists) ->
        if err then throw err
        if albumsExists and thumbsExists and uploadsExists then return null
        if not albumsExists then fs.mkdir self.albumDir, 0755, @parallel ()
        if not thumbsExists then fs.mkdir self.thumbDir, 0755, @parallel ()
        if not uploadsExists then fs.mkdir self.uploadDir, 0755, @parallel ()
        return undefined

      # create akismet client
      (err) ->
        if err then throw err
        if self.settings.akismetKey and self.settings.akismetURL
          self.akismetClient = akismet.client { apiKey: self.settings.akismetKey, blog: self.settings.akismetURL }
          self.akismetClient.verifyKey @
          return undefined
        return null

      # execute callback
      (err, verified) ->
        if err then throw err

        # check akismet
        if verified is false
          util.log 'Could not verify Akismet key.'
          self.akismetClient = null

        # watch uploads
        self.monitor = new UploadMonitor(self.db, self.albumDir, self.thumbDir, self.uploadDir)
        self.monitor.start ()

        self.albums = new Albums(self.db)
        self.pictures = new Pictures(self.db)
        self.comments = new Comments(self.db, self.akismetClient)

        util.log 'Application initialized.'
        callback (err)
    )


module.exports = new CanPhotoBlog

