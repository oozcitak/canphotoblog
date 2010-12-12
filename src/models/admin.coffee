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
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.akismetKey, 'akismetKey'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.akismetURL, 'akismetURL'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.gaKey, 'gaKey'], group()
        self.db.execute 'UPDATE "Settings" SET "value"=? WHERE "name"=?', [settings.thumbSize, 'thumbSize'], group()
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
        if not verified
          akismetClient = null
        app.set 'akismet', akismetClient

        callback err, verified

    )


module.exports = Admin

