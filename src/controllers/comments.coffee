util = require 'util'
step = require 'step'

app = module.parent.exports
db = app.set 'db'
akismet = app.set 'akismet'
settings = app.set 'settings'

Comments = require '../models/comments'
comments = new Comments db, akismet


# POST /comments/add
app.post '/comments/add', (req, res) ->

  if settings.allowComments
    album = req.body.album
    picture = req.body.picture or null
    name = req.body.from
    text = req.body.text

    if picture
      comments.addToPicture album, picture, name, text, req, (err) ->
        res.redirect '/pictures/' + album + '/' + picture
    else
      comments.addToAlbum album, name, text, req, (err) ->
        res.redirect '/albums/' + album
  else
    throw new Error('Comments not allowed.')
    res.redirect '/'


# GET /comments
app.get '/comments', (req, res) ->

  page = req.query.page || 1

  step(

    # get commented albums
    () ->
      comments.getCommentedPictures page, settings.picturesPerPage, @parallel()
      comments.countCommentedPictures @parallel()
      return undefined

    # render page
    (err, comments, count) ->
      if err then throw err

      app.helpers { pageCount: Math.ceil(count / settings.picturesPerPage) }

      res.render 'comments', {
          locals: {
            comments: comments
          }
        }

  )


# GET /comments/edit
app.get '/comments/edit/:id', (req, res) ->

  if req.session.userid
    id = req.params.id

    comments.get id, (err, comment) ->
      res.render 'editcomment', {
          locals: {
            comment: comment
          }
        }

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# POST /comments/edit
app.post '/comments/edit/:id', (req, res) ->

  if req.session.userid
    id = req.params.id
    name = req.body.name
    text = req.body.text

    comments.edit id, name, text, (err) ->
      res.redirect 'back'

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'
  

# GET /comments/delete
app.get '/comments/delete/:id', (req, res) ->

  if req.session.userid
    id = req.params.id

    comments.delete id, (err) ->
      res.redirect 'back'

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# GET /comments/spam
app.get '/comments/spam/:id', (req, res) ->

  if req.session.userid
    id = req.params.id

    comments.markSpam id, (err) ->
      res.redirect 'back'

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'


# GET /comments/ham
app.get '/comments/ham/:id', (req, res) ->

  if req.session.userid
    id = req.params.id

    comments.markHam id, (err) ->
      res.redirect 'back'

  else
    req.flash 'error', 'Access denied.'
    res.redirect '/login'
 
