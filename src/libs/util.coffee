path = require 'path'
crypto = require 'crypto'


# Utility functions
module.exports = {

  # Ensures that the callback is a function
  # 
  # callback: the callback to check
  ensureCallback: (callback) ->
    def = () ->
    callback or= def


  # path.exists with err argument
  #
  # file: path to a file
  # callback: err, exists (true or false)
  fileExists: (file, callback) ->
    callback = @ensureCallback callback
    path.exists file, (exists) ->
      callback null, exists


  # Joins object and returns the resulting object
  #
  # a, b: objects to join
  joinObjects: (a, b) ->
    c = a
    for item in b
      c[item.name] = item.value
    return c


  # Hashes the given data and returns the digest
  #
  # data: the data to hash
  # algo: hashing algorithm, defaults to 'sha1'
  # enc: encoding, defaults to 'hex'
  hash: (data, algo, enc) ->
    algo or= 'sha1'
    enc or= 'hex'
    return crypto.createHash(algo).update(data).digest(enc)


  # Hashes the given string with a random salt.
  # Returns the salt hash prepended to the hashed string.
  #
  # input: the string to hash
  # salt: the hash salt. null to generate a random salt
  makeHash: (input, salt) ->
    inputHash = @hash input
    if not salt or salt.length isnt 32
      salt = @hash Math.random(), 'md5'
    return salt + @hash(inputHash + salt)


  # Determines whether the input string matches the hashed string.
  # Returns true if the strings match; otherwise false.
  #
  # input: the string to check
  # hashed: the hashed string to check against
  checkHash: (input, hashed) ->
    salt = hashed.substr 0, 32
    inputHash = @makeHash input, salt
    return hashed is inputHash


  # Converts a Date object to sqlite date string formatted as
  # YYYY-MM-DD HH:MM:SS.
  #
  # date: a date object
  # time: true to include time, defaults to true
  dateToSQLite: (date, time) ->
    if not time? then time = true

    y = date.getFullYear()
    m = date.getMonth() + 1
    d = date.getDate()
    hh = date.getHours()
    mm = date.getMinutes()
    ss = date.getSeconds()

    if m < 10 then m = '0' + m
    if d < 10 then d = '0' + d
    if hh < 10 then hh = '0' + hh
    if mm < 10 then mm = '0' + mm
    if ss < 10 then ss = '0' + ss

    if time
      return y + '-' + m + '-' + d + ' ' + hh + ':' + mm + ':' + ss
    else
      return y + '-' + m + '-' + d

}

