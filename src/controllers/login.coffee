util = require 'util'
step = require 'step'

app = module.parent.exports.expressApp
db = app.set 'db'
settings = app.set 'settings'

Users = require '../models/users'
users = new Users db


# GET /login
app.get '/login', (req, res) ->
  res.render 'login'


# GET /logout
app.get '/logout', (req, res) ->
  
  step(

    # destroy session
    () ->
      req.session.destroy @
      return undefined

    # return to home page
    (err) ->
      if err then throw err
      res.redirect '/'

  )


# POST /login
app.post '/login', (req, res) ->

  username = req.body.username
  password = req.body.password
  cuser = null

  step(

    # try login
    () ->
      app.set 'user', null
      users.login username, password, @
      return undefined
    
    # check user
    (err, user) ->
      if err then throw err
      cuser = user
      if cuser
        req.session.regenerate @
        return undefined
      else
        req.flash 'error', 'Login failed. Please check your username and password.'
        res.redirect '/login'
        return null

    # save user id
    (err) ->
      if err then throw err
      if cuser
        app.set 'user', cuser
        req.session.userid = cuser.id
        res.redirect '/'

    )

