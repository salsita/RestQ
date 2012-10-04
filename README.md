#RestQ
RestQ is a little helper module that allows us to follow RESTful API links in a more declarative style.

### Why is that cool?

OK, let's say we have a server that exposes a `/posts/42.json` resource, which
contains an `{"author": {"person_id": "foo"}}` link to a `/people/<person_id>.json` 
resource. And we want to get the post author's email.

One way would be to do something like this:

    request.get('http://server.com/posts/42.json, (err, res, body) ->
      if err or res.statusCode isnt 200
        # Handle errors here...
      request.get('http://server.com/people/#{body.author.id}.json), (err, res, body) ->
        if err or res.statusCode isnt 200
          # Handle errors here.
        email = body['email-address']
        
Now that's not too terrible, but it's not awesome either. 
The nesting is kind of annoying (imagine what happens when there are more levels...) 
and the code is just not as readable as it could be.

#### So how does RestQ help?
Well, with RestQ, we can call:

    emailPromise = RQ.from('http://server.com/posts/42.json')
      .via('/people/{author.id}.json')
      .get('email-address')
      
And we get a 'thenable' (promise) for the post author's email stored in `emailPromise`.

Now when we need the actual email address, we do:
   
    p.then (email) -> ... email is here ...

et voila!


## Installation
    npm install restq

### Kudos to
[Underscore](https://github.com/documentcloud/underscore/),
 [Underscore.string](https://github.com/epeli/underscore.string),
 [Q](https://github.com/kriskowal/q),
 [Request](https://github.com/mikeal/request) 