'
' An OAuth 1.0a client
'
Function OAuth1a(key as String, secret as String) As Object
    client = {
        ' Holds the consumer (aka API) key and secret
        consumerKey: key,
        consumerSecret: secret,
        token: Invalid,
        tokenSecret: Invalid,

        userAgent: "Roku/0.0.0",

        ' internal instances
        urlTransfer: CreateObject("roUrlTransfer")

        ' Response data
        lastResponse: Invalid,

        ' public methods
        getLastResponse: getLastResponse,
        fetch: fetch,
        setToken: setToken,

        ' private methods
        _getNonce: _getNonce,
        _getSbs: _getSbs,
        _getSecret: _getSecret,
        _getSignatureParameters: _getSignatureParameters,
        _getTimestamp: _getTimestamp,
        _parseQueryStringToObject: _parseQueryStringToObject,
        _log: _log
    }

    return client
End Function

' todo - this doesn't work for POST data yet :facepalm: need to merge incoming parameter list with the oauth signature values
Function fetch(url as String, postData = {} as Object, method = "GET" as String, headers = {} as Object) As Boolean
    m._log("fetch(""" + url + """) via " + method)

    ' Collect parameters to create the based string and create the signature
    oauthParameters = m._getSignatureParameters()
    sbsByteArray = CreateObject("roByteArray")
    sbsByteArray.fromAsciiString(m._getSbs(method, url, oauthParameters))
    secretKeyByteArray = CreateObject("roByteArray")
    secretKeyByteArray.fromAsciiString(m._getSecret())
    hmac = CreateObject("roHMAC")
    hmac.setup("sha1", secretKeyByteArray)

    ' Build the authorization header from the base string and oauth specific parameters
    oauthParameters.addReplace("oauth_signature", hmac.process(sbsByteArray).toBase64String())
    authorizationHeader = "OAuth "
    for each key in oauthParameters
        authorizationHeader = authorizationHeader + key + "=" + chr(34) + m.urlTransfer.escape(oauthParameters[key]) + chr(34) + ","
    end for

    ' Request the data!
    m.urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    m.urlTransfer.setUrl(url)
    m.urlTransfer.addHeader("Accept", "application/json")
    m.urlTransfer.addHeader("Authorization", Left(authorizationHeader, len(authorizationHeader) - 1))
    m.urlTransfer.addHeader("User-Agent", m.userAgent)

    if ("GET" = method)
        response = m.urlTransfer.getToString()
        m._log("Response: " + response)
        m.lastResponse = ParseJson(response)
    else if ("HEAD" = method)
        m.lastResponse = Invalid
        m.urlTransfer.head()
    else if ("POST" = method)
        ' todo build the post data string
        response = m.urlTransfer.postFromString()

        m._log("http status code " + response.toStr())
        m.lastResponse = {} ' the component tosses the response body
    end if

    return true
End Function

Function getLastResponse()
    return m.lastResponse
End Function

Sub setToken(token as String, secret as String)
    m.token = token
    m.tokenSecret = secret
End Sub

' Generates a random string to use for the nonce
Function _getNonce(desiredLength = 12 as Integer) as String
    values = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")
    nonce = ""
    while (Len(nonce) < desiredLength)
        nonce = nonce + values[Rnd(values.count() - 1)]
    end while
    return nonce
End Function

' Gets the unix epoch timestamp
Function _getTimestamp() as String
    now = CreateObject("roDateTime")
    return now.AsSeconds().toStr()
End Function

Function _getSbs(method as String, url as String, parameters = {} as Object) as String
    method = UCase(method)
    queryParameters = {}
    if ("GET" = method and Instr(1, url, "?") > 1)
        ' split off any query params and merge with existing parameters
        queryString = Right(url, Len(url) - Instr(1, url, "?"))
        url = Left(url, Instr(1, url, "?") - 1)
        queryParameters = m._parseQueryStringToObject(queryString)
    end if

    for each key in parameters
        queryParameters.addReplace(key, parameters[key])
    end for

    ' sort the params & query parameters and rebuild
    sortedParameters = queryParameters.items()
    sortedParameters.sortBy("key")
    requestParameters = ""
    for each item in sortedParameters
        if (Len(requestParameters) > 0)
            requestParameters = requestParameters + "&"
        end if
        requestParameters = requestParameters + m.urlTransfer.escape(item.key) + "=" + m.urlTransfer.escape(item.value)
    end for

    return m.urlTransfer.escape(method) + "&" + m.urlTransfer.escape(url) + "&" + m.urlTransfer.escape(requestParameters)
End Function

Function _getSignatureParameters()
    result = {}
    result.addReplace("oauth_consumer_key", m.consumerKey)
    result.addReplace("oauth_nonce", m._getNonce())
    result.addReplace("oauth_signature_method", "HMAC-SHA1")
    result.addReplace("oauth_timestamp", m._getTimestamp())
    if (m.token <> Invalid)
        result.addReplace("oauth_token", m.token)
    end if
    result.addReplace("oauth_version", "1.0")
    return result
End Function

Function _getSecret() as String
    return m.urlTransfer.escape(m.consumerSecret) + "&" + m.urlTransfer.escape(m.tokenSecret)
End Function

Function _parseQueryStringToObject(queryString as string)
    data = {}
    for each pair in queryString.split("&")
        keyValue = pair.split("=")
        data.addReplace(m.urlTransfer.unescape(keyValue[0]), m.urlTransfer.unescape(keyValue[1]))
    end for
    return data
End Function

Sub _log(message as String)
    now = CreateObject("roDateTime")
    now.toLocalTime()
    print now.ToISOString() + ": Oauth1a: " + message
End Sub