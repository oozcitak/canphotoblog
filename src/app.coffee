express = require 'express'
path = require 'path'
fs = require 'fs'
util = require 'util'
url = require 'url'
step = require 'step'
akismet = require 'akismet'
sqlite = require 'sqlite'
cutil = require './libs/util'


# set the environment to production
process.env.NODE_ENV = 'development'


# Configure and start server
app = express.createServer()
app.configure () ->

  dbexists = true
  db = null
  settings = {}

  step(

    # settings
    () ->
      appRoot = path.dirname __dirname

      # express settings
      app.set 'view engine', 'haml'
      app.set 'views', path.join(appRoot, 'views')

      app.use express.bodyDecoder()
      app.use express.cookieDecoder()
      app.use express.session()

      # settings
      settings = {
        rootDir: appRoot
        publicDir: path.join appRoot, 'public'
        albumDir: path.join appRoot, 'public', 'albums'
        thumbDir: path.join appRoot, 'public', 'thumbs'
        uploadDir: path.join appRoot, 'uploads'
        dbFile: path.join appRoot, 'album.sqlite'
        akismetClient: null
      }

      # check database
      cutil.fileExists settings.dbFile, @
      return undefined

    # open database
    (err, exists) ->
      if err then throw err
      dbexists = exists
      db = new sqlite.Database()
      app.set 'db', db
      db.open settings.dbFile, @
      return undefined

    # make database if it does not exist
    (err) ->
      if err then throw err

      if dbexists
        return null
      else
        db.executeScript 'DROP TABLE IF EXISTS "Albums";' +
          'DROP TABLE IF EXISTS "Pictures";' +
          'DROP TABLE IF EXISTS "Comments";' +
          'DROP TABLE IF EXISTS "Settings";' +
          'DROP TABLE IF EXISTS "Users";' +
          'CREATE TABLE "Albums" ("id" INTEGER PRIMARY KEY, "name", "dateCreated", "title", "text");' +
          'CREATE TABLE "Pictures" ("id" INTEGER PRIMARY KEY, "name", "dateTaken", "album", "title", "text");' +
          'CREATE TABLE "Comments" ("id" INTEGER PRIMARY KEY, "from", "text", "dateCommented", "album", "picture", "spam", "ip");' +
          'CREATE TABLE "Users" ("id" INTEGER PRIMARY KEY, "name", "password");' +
          'CREATE TABLE "Settings" ("name" PRIMARY KEY, "value");' +
          'CREATE INDEX "albums_name" ON "Albums" ("name");' +
          'CREATE INDEX "pictures_name" ON "Pictures" ("name");' +
          'CREATE INDEX "pictures_album" ON "Pictures" ("album");' +
          'CREATE INDEX "comments_album" ON "Comments" ("album");' +
          'CREATE INDEX "comments_picture" ON "Comments" ("picture");' +
          'CREATE INDEX "comments_spam" ON "Comments" ("spam");' +
          'INSERT INTO "Users" ("name", "password") VALUES ("admin", "' + cutil.makeHash('admin') + '");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("albumsPerPage", "20");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("picturesPerPage", "40");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("allowComments", "1");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("monitorInterval", "1");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("appName", "canphotoblog");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("appTitle", "canphotoblog");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("backgroundColor", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("backgroundImage", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("akismetKey", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("akismetURL", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("gaKey", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("thumbSize", "150");', @
        return undefined
          
    # read settings
    (err) ->
      if err then throw err
      db.execute 'SELECT * FROM "Settings"', @
      return undefined

    # add to app settings
    (err, rows) ->
      if err then throw err
      if not rows then throw new Error('Unable to read application settings.')

      settings = cutil.joinObjects settings, rows
      app.set 'settings', settings

      # check folders
      cutil.fileExists settings.albumDir, @parallel()
      cutil.fileExists settings.thumbDir, @parallel()
      cutil.fileExists settings.uploadDir, @parallel()
      return undefined

    # create directories
    (err, albumsExists, thumbsExists, uploadsExists) ->
      if err then throw err
      if albumsExists and thumbsExists and uploadsExists then return null

      if not albumsExists then fs.mkdir settings.albumDir, 0755, @parallel()
      if not thumbsExists then fs.mkdir settings.thumbDir, 0755, @parallel()
      if not uploadsExists then fs.mkdir settings.uploadDir, 0755, @parallel()
      return undefined

    # create akismet client
    (err) ->
      if err then throw err

      if settings.akismetKey and settings.akismetURL
        akismetClient = akismet.client { apiKey: settings.akismetKey, blog: settings.akismetURL }
        app.set 'akismet', akismetClient
        akismetClient.verifyKey @
        return undefined
      else
        return null

    # end of config
    (err, verified) ->
      if err then throw err

      # check akismet
      if verified is true
        util.log 'Verified Akismet key'
      else if verified is false
        util.log 'Could not verify Akismet key.'
        app.set 'akismet', null
      else if verified is null
        util.log 'Akismet key does not exist.'
        app.set 'akismet', null

      # start upload monitor
      UploadMonitor = require './libs/monitor'
      monitor = new UploadMonitor(db, settings.albumDir, settings.thumbDir, settings.uploadDir, settings.thumbSize, settings.monitorInterval * 60 * 1000)
      monitor.start()
      app.set 'monitor', monitor

      # default controller
      app.get '*', (req, res, next) ->
        app.helpers {
          pageCount: 0
          pagetitle: ''
          pageCount: 0
          album: null
          picture: null
        }
        next()

      # include controllers
      for file in fs.readdirSync path.join(__dirname, 'controllers')
        filename = path.join __dirname, 'controllers', file
        if fs.statSync(filename).isFile()
          require './controllers/' + path.basename(file, path.extname(file))

      # if no routes match fall to 404
      app.get '*', (req, res, next) ->
        res.render '404', {
            layout: false
          }


      # dynamic view helpers
      app.dynamicHelpers {

        # settings
        appname: (req, res) ->
          return app.set('settings').appName
        apptitle: (req, res) ->
          return app.set('settings').appTitle
        gakey: (req, res) ->
          return app.set('settings').gaKey
        settings: (req, res) ->
          return app.set('settings')

        # returns array of pagination objects
        pagination: (req, res) ->
          pages = app.viewHelpers.pageCount
          if pages <= 1
            return null
          else
            return cutil.getPagination req.url, pages

        # returns an array of error messages
        errorMessages: (req, res) ->
          msg = req.flash 'error'
          if not msg or msg.length is 0 then msg = null
          return msg

        # returns an array of info messages
        infoMessages: (req, res) ->
          msg = req.flash 'info'
          if not msg or msg.length is 0 then msg = null
          return msg

        # gets the logged in user
        user: (req, res) ->
          userid = if req.session.userid then req.session.userid else null
          user = app.set 'user'
          if user and user.id is userid then return user else return null

      }

      # start listening
      app.listen 8124
      util.log 'Application started.'
  )


# clean-up
process.on 'exit', () ->
  monitor = app.set 'monitor'
  if monitor then monitor.stop()


module.exports = app

