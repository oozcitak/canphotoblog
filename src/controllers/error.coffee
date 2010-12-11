util = require 'util'

app = module.parent.exports

# Errors
app.error (err, req, res) ->
  util.log err
  res.render '500', {
      layout: false,
      locals: { message: err.message }
    }

