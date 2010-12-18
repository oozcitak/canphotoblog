util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Users = require '../models/users'
users = new Users db
Admin = require '../models/admin'
admin = new Admin db


# GET /admin
app.get '/admin', (req, res) ->
  if req.session.userid
    admin.getBackgrounds app, (err, images) ->
      res.render 'admin', {
          locals: {
            pagetitle: 'Blog Administration'
            bgimages: images
          }
        }
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin
app.post '/admin', (req, res) ->
  if req.session.userid
    settings.appName = req.body.name
    settings.appTitle = req.body.title
    settings.albumsPerPage = parseInt req.body.albums
    settings.picturesPerPage = parseInt req.body.pictures
    settings.monitorInterval = parseInt req.body.monitorinterval
    settings.thumbSize = parseInt req.body.thumbsize
    settings.allowComments = if req.body.allowcomments then 1 else 0
    settings.akismetKey = req.body.akismetkey
    settings.akismetURL = req.body.akismeturl
    settings.gaKey = req.body.gakey

    admin.changeSettings app, settings, (err, verified) ->
      if err then throw err
      req.flash 'info', 'Settings saved.'
      if verified
        req.flash 'info', 'Akismet key verified.'
      else
        req.flash 'error', 'Could not verify Akismet key.'
      res.redirect '/admin'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/background
app.post '/admin/style', (req, res) ->
  if req.session.userid
    settings.backgroundColor = req.body.bgcolor
    settings.backgroundImage = req.body.bgimage

    admin.changeStyle app, settings, (err) ->
      if err then throw err
      req.flash 'info', 'Background settings saved.'
      res.redirect '/admin'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/password
app.post '/admin/password', (req, res) ->
  if req.session.userid
    users.changePassword req.session.userid, req.body.password, (err) ->
      if err then throw err
      req.flash 'info', 'Password changed.'
      res.redirect '/admin'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'

