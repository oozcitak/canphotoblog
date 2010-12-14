step = require 'step'
cutil = require '../libs/util'
util = require 'util'

class Users


  # Creates a new Users object
  #
  # db: database connection object
  constructor: (db) ->
    @db = db


  # Logs in the given user
  #
  # username: user name
  # password: user password
  # callback: err, user object (null if login fails)
  login: (username, password, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get user
      () ->
        self.db.execute 'SELECT * FROM "Users" WHERE "name"=? LIMIT 1', [username], @
        return undefined

      # check password
      (err, rows) ->
        if err then throw err

        user = null
        if rows and rows.length is 1 and cutil.checkHash password, rows[0].password
          user = rows[0]

        callback err, user

    )


  # Gets the user with the given id
  #
  # id: user id
  # callback: err, user (null if there is no user with this id)
  get: (id, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get user
      () ->
        self.db.execute 'SELECT * FROM "Users" WHERE "id"=? LIMIT 1', [id], @
        return undefined

      # read user
      (err, rows) ->
        if err then throw err

        user = null
        if rows and rows.length is 1 then user = rows[0]

        callback err, user

    )


  # Changes the password of the given user
  #
  # id: user id
  # password: user password
  # callback: err
  changePassword: (id, password, callback) ->

    callback = cutil.ensureCallback callback
    self = @

    step(

      # get user
      () ->
        hash = cutil.makeHash password
        self.db.execute 'UPDATE "Users" SET "password"=? WHERE "id"=?', [hash, id], @
        return undefined

      # execute callback
      (err) ->
        if err then throw err
        callback err

    )


module.exports = Users

