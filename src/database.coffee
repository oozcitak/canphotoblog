util = require 'util'
step = require 'step'
sqlite = require 'sqlite'
cutil = require './util'


class Database


  # Creates a new Database connection
  #
  # dbFile: path to SQLite file
  constructor: (dbFile) ->
    @dbFile = dbFile


  # Initializes the database
  #
  # callback: err, database object, key/value pairs of settings
  init: (callback) ->

    callback = cutil.ensureCallback callback
    dbexists = true
    self = @

    step(
     
      # check database
      () ->
        cutil.fileExists self.dbFile, @
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

      # execute callback
      (err, settings) ->
        if err then throw err
        callback err, self.db, settings
    )


  # Creates the album database
  #
  # callback: err
  makeDatabase: (callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # make tables
      () ->
        self.db.executeScript 'DROP TABLE IF EXISTS "Albums";' +
          'DROP TABLE IF EXISTS "Pictures";' +
          'DROP TABLE IF EXISTS "Comments";' +
          'DROP TABLE IF EXISTS "Settings";' +
          'CREATE TABLE "Albums" ("name", "path", "title", "text");' +
          'CREATE TABLE "Pictures" ("name", "path", "dateTaken", "album", "title", "text");' +
          'CREATE TABLE "Comments" ("from", "text", "dateCommented", "album", "picture", "spam", "ip");' +
          'CREATE TABLE "Settings" ("name", "value");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("albumsPerPage", "20");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("picturesPerPage", "40");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("appName", "canphotoblog");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("appTitle", "canphotoblog");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("akismetKey", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("akismetURL", "");' +
          'INSERT INTO "Settings" ("name", "value") VALUES ("thumbSize", "150");', @

        return undefined

      # execute callback
      (err) ->
        if err then throw err
        util.log 'Created album database.'
        callback err
    )


  # Reads application settings
  #
  # callback: err, key/value pairs of settings
  readSettings: (callback) ->

    callback = cutil.ensureCallback callback
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

        settings = {}
        for item in rows
          settings[item.name] = item.value

        callback err, settings
    )


module.exports = Database

