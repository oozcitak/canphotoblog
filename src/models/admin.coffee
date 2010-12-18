util = require 'util'
fs = require 'fs'
path = require 'path'
step = require 'step'
akismet = require 'akismet'
cutil = require '../libs/util'


class Admin


  # Creates a new Admin object
  #
  # db: database connection object
  constructor: (db) ->
    @db = db


  # Saves and applies settings
  #
  # app: the application object to apply settings to
  # settings: new settings
  # callback err, verified (true if Akismet verified)
  changeSettings: (app, settings, callback) ->

    callback = cutil.ensureCallback callback
    self = @
    akismetClient = null

    step(

      # save settings
      () ->
        app.set 'settings', settings
        group = @group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.appName, 'appName'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.appTitle, 'appTitle'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.albumsPerPage, 'albumsPerPage'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.picturesPerPage, 'picturesPerPage'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.monitorInterval, 'monitorInterval'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.thumbSize, 'thumbSize'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.allowComments, 'allowComments'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.akismetKey, 'akismetKey'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.akismetURL, 'akismetURL'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.gaKey, 'gaKey'], group()
        return undefined

      # create akismet client
      (err) ->
        if err then throw err

        if settings.akismetKey and settings.akismetURL
          akismetClient = akismet.client { apiKey: settings.akismetKey, blog: settings.akismetURL }
          akismetClient.verifyKey @
          return undefined
        else
          return null
        return undefined

      # verify akismet client
      (err, verified) ->
        if err then throw err
        if not verified
          akismetClient = null
        app.set 'akismet', akismetClient

        callback err, verified

    )


  # Gets a list of background images
  #
  # app: the application object
  # callback: err, array of image names
  getBackgrounds: (app, callback)->

    dir = path.join app.set('settings').publicDir, 'img', 'backgrounds'
    self = @

    step(

      # get folder contents
      () ->
        fs.readdir dir, @
        return undefined

      # execute callback
      (err, fileNames) ->
        if err then throw err

        files = []
        for fileName in fileNames
          if path.extname(fileName).toLowerCase() is '.jpg'
            files.push fileName
        files.sort()
 
        callback err, files

    )


  # Saves and applies style settings
  #
  # app: the application object to apply settings to
  # settings: new settings
  # callback err
  changeStyle: (app, settings, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # save settings
      () ->
        app.set 'settings', settings
        group = @group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.backgroundColor, 'backgroundColor'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.backgroundImage, 'backgroundImage'], group()
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err

    )


module.exports = Admin

