# OAuth 1.0a Request Client

A client for making OAuth 1.0a signed requests using BrightScript for Roku apps. This is a work in progress.

## Example Usage
```
' create the client
oauthClient = OAuth1a("abc123-consumerKey-xyz", "zyx-consumerSecret-cba")

' provide the access token
oauthClient.setToken("abc-accessToken-xyz", "zyx-accessTokenSecret-cba")

' make a request
if (oauthClient.fetch("https://api.example.com/v1/user"))
    response = oauthClient.getLastResponse()
    print response
else
    print "Request failed"
end if
```

### TODO
* Handle `POST` requests
* Handle `DELETE` requests
* Handle `PUT` requests
* Move request handling into a `Task`
