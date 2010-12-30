util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
settings = app.set 'settings'

Users = require '../models/users'
users = new Users db
Admin = require '../models/admin'
admin = new Admin db, settings.albumDir, settings.thumbDir, settings.thumbSize


# GET /admin
app.get '/admin', (req, res) ->
  if req.session.userid

    step(

      #read resources
      () ->
        admin.getStyles app, @parallel()
        admin.getBackgrounds app, @parallel()
        return undefined

      # render page
      (err, styles, images) ->
        if err then throw err
        res.render 'admin', {
            locals: {
              pagetitle: 'Blog Administration'
              styles: styles
              bgimages: images
            }
          }

    )

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/app
app.post '/admin/app', (req, res) ->
  if req.session.userid
    appName = req.body.name
    appTitle = req.body.title
    appAuthor = req.body.author
    monitorInterval = parseInt req.body.monitorinterval

    admin.changeAppSettings app, appName, appTitle, appAuthor, monitorInterval, (err) ->
      if err then throw err
      req.flash 'info', 'Application settings saved.'
      res.redirect '/admin#app'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/view
app.post '/admin/view', (req, res) ->
  if req.session.userid
    albumsPerPage = parseInt req.body.albums
    picturesPerPage = parseInt req.body.pictures
    thumbSize = parseInt req.body.thumbsize

    if req.body.rebuildthumbs?
      res.redirect '/admin/rebuildthumbs/'
      return

    admin.changeViewSettings app, albumsPerPage, picturesPerPage, thumbSize, (err) ->
      if err then throw err
      req.flash 'info', 'View settings saved.'
      res.redirect '/admin#view'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/comments
app.post '/admin/comments', (req, res) ->
  if req.session.userid
    allowComments = if req.body.allowcomments then 1 else 0
    akismetKey = req.body.akismetkey
    akismetURL = req.body.akismeturl

    admin.changeCommentSettings app, allowComments, akismetKey, akismetURL, (err, verified) ->
      if err then throw err
      req.flash 'info', 'Comment settings saved.'
      if verified
        req.flash 'info', 'Akismet key verified.'
      else
        req.flash 'error', 'Could not verify Akismet key.'
      res.redirect '/admin#comments'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/analytics
app.post '/admin/analytics', (req, res) ->
  if req.session.userid
    admin.changeAnalyticsSettings app, req.body.gakey, (err) ->
      if err then throw err
      req.flash 'info', 'Analytics settings saved.'
      res.redirect '/admin#analytics'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/style
app.post '/admin/style', (req, res) ->
  if req.session.userid
    admin.changeStyle app, req.body.style, req.body.bgcolor, req.body.bgimage, (err) ->
      if err then throw err
      req.flash 'info', 'Style settings saved.'
      res.redirect '/admin#style'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /admin/password
app.post '/admin/password', (req, res) ->
  if req.session.userid
    users.changePassword req.session.userid, req.body.password, (err) ->
      if err then throw err
      req.flash 'info', 'Password changed.'
      res.redirect '/admin#password'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# GET /admin/rebuildthumbs
app.get '/admin/rebuildthumbs', (req, res) ->
  if req.session.userid
    admin.rebuildThumbs()

    admin.emitter.on 'progress', (percent) ->
      req.flash 'info', 'Rebuilding thumbnails... ' + percent + '% completed.'
      util.log 'Rebuilding thumbnails... ' + percent + '% completed.'

    admin.emitter.on 'complete', (err) ->
      if err then throw err
      req.flash 'info', 'Completed rebuilding thumbnails.'

    req.flash 'info', 'Rebuilding thumbnails...'
    res.redirect '/admin#view'
  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'

