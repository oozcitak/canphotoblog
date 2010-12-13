util = require 'util'

app = module.parent.exports

# Errors
app.error (err, req, res) ->
  res.render '500', {
      layout: false,
      locals: { message: err.message }
    }

