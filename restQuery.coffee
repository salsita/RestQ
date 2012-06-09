
###
RestQuery - a declarative way to query RESTful APIs to get the data we need.
###

Q = require 'q'
request = require 'request'

_ = require 'underscore'
_.str = require 'underscore.string'
_.mixin _.str.exports()

url = require 'url'

# Replaces "{foo}"-like placeholders in `str` with values from `obj`.
# Example:
#     > resolvePlaceholders 'blah {a.b} bar', a: b: 'foo'
#     > 'blah foo bar'
resolvePlaceholders = (str, obj) ->
    placeholders = str.match(/{[^}]+}/g)
    _.reduce placeholders,
      (memo, placeholder) ->
        value = deep obj, (_.trim placeholder, '{}')
        memo.replace placeholder, value
      , str


# Returns deep property of `obj` specified by `path`.
# Example:
#     > deep a: b: 'c', 'a.b'
#     > 'b'
# We expect that `obj` fields do not contain dots.
# Pass '.' as the path to get the whole object.
#     > deep a: b: 'c', '.'
#     > {a: {b: 'c'}}
deep = (obj, path) ->
  return obj if path is '.'
  _.reduce path.split('.'), ((memo, part) -> memo[part]), obj


# This class allows us to follow RESTful API link in a declarative style.
#
# Why is that cool?
#
# Let's say we have a server that exposes `/posts/42.json` resource, which
# contains `author_id` link to `/people/<id>.json` resource. We want to get
# the post author's email.
# So we call:
#     p = RQ.from('http://server.com/posts/42.json')
#       .via('/people/{author_id}.json')
#       .get('email-address')
# And we get a 'thenable' (promise) for the post author's email stored in `p`.
# Now when we need the actual email address, we call:
#     p.then (email) -> ... email is here ...
# et voila!
class RestQuery
  constructor: (startUrl, promise = null) ->
    @_url = url.parse startUrl
    @_promise = promise or @_GET startUrl


  _GET: (url) ->
    deferred = Q.defer()
    request.get url, json: true, (err, res, body) ->
      if err or res.statusCode isnt 200
        deferred.reject JSON.stringify(err or body)
      deferred.resolve body
    return deferred.promise


  # Use this method to GET a resource linked from a previously retrieved one.
  # Example:
  #     RQ.from('http://a.a/foo/12.json).via('/bar/{bar_id}.json).get('baz')
  # This will first load 'foo' resource with id 12 (that has a 'bar_id' field),
  # then a 'bar' resource with id we got from 'foo' and finally return
  # a promise for 'baz' field of the bar resource.
  via: (where) ->
    p = @_promise.then (val) =>
      resolvedUrl = resolvePlaceholders where, val
      if resolvedUrl[0] is '/'
        # We got a relative URL => run it into an absolute one.
        absUrl = url.resolve(@_url, resolvedUrl)
      else
        absUrl = resolvedUrl
      return @_GET absUrl

    # Return new RestQuery so that multiple queries may share the same
    # 'root query' (otherwise @_promise would get overwritten).
    return new RestQuery (url.format @_url), p

  # Returns a thenable that resolves to the (deep) property of the resource
  # `get` is called on.
  get: (what) ->
    @_promise.then (val) ->
      res = deep val, what
      if _.isUndefined res
        throw new Error "Acceessing field '#{what}' which is not defined."
      else
        return res


exports.from = (url) -> new RestQuery(url)
