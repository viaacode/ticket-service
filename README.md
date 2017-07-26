# ticket-service

Ticket-service generates authentication tokens.
A typical use case is to provide third party access to VIAA media content.
The token is requested by a trusted application on behalf of a user.
It restricts access to a given named object based on clientip and user agent and has an expiration timestamp.

The token contains
* an application id
* an expiration date
* a signature

The signature is a cryptographic hash over the concatenation of
* request verb
* a name (e.g. an uri)
* user agent string
* expiration
* client IP address 

The token is formatted as a [JSON Web token (JWT)](https://jwt.io/).
The signature covers data that is external to the token. The JWT is
not signed (`alg: 'none'`) but carries the signature in the `sig` claim,
because the signature covers data that is external to the token.

```json
{
    "aud": "<application id>",
    "exp": "<expiration time>",
    "sig": "<signature, base64 encoded>"
}
```

## Examples

### Simple token request for an arbitrary name

#### Request

```bash
curl -X GET --key mycert.key --cert mycert.cert -d '{
  "app": "org1",
  "useragent": "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0",
  "verb": "GET",
  "client": "127.0.0.1"
  }' http://api.example.org/ticket/TESTBEELD/example/browse.mp4
```

#### Response

```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJhdWQiOiJvcmcxIiwiZXhwIjoxNDk2MjI5NzYwLCJzaWciOiJXMTFNeFZjRkR1cC9IM29oamVadm52VTFYRURVUGN0QVM3d1JHK0RGWEJFPSJ9.",
  "context": {
    "app": "org1",
    "verb": "GET",
    "name": "TESTBEELD/example/browse.mp4",
    "useragent": "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0",
    "client": "127.0.0.1",
    "expiration": "2017-05-31 13:22:40 +0200"
  }
}
```

### Request with object availability check

By specifying the `format`parameter, the service will check if the content for which a token is requested is available in the requested formats. It will then return an array with tokens for each format in whcih the content is available at VIAA. If the content does not exist, the response will be 404.

#### Request

```bash
curl -X GET --key mycert.key --cert mycert.cert -d '{
{
  "app" : "org1",
  "useragent": "mpv 0.26.0",
  "verb": "GET",
  "client": "84.199.20.186",
  "maxage": 900,
  "format": [ "m3u8", "webm", "mp4" ]
} http://api.example.org/ticket/TESTBEELD/example/browse.mp4
```

#### Response

```json
{
  "total": 2,
  "name": "TESTBEELD/example/browse",
  "results": [
    {
      "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJhdWQiOiJvcmcxIiwiZXhwIjoxNTAxMDcwMDA3LCJzaWciOiJxT2xyaGhzT1dZTmxvWjdXT1hWNlVWL1dmQ3ZhdVdQdVY4a0ZWZTNmT1pJPSJ9.",
      "app": "org1",
      "verb": "GET",
      "name": "TESTBEELD/example/browse.m3u8",
      "useragent": "mpv 0.26.0",
      "client": "84.199.20.186",
      "expiration": "2017-07-26 13:53:27 +0200"
    },
    {
      "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJhdWQiOiJvcmcxIiwiZXhwIjoxNTAxMDcwMDA3LCJzaWciOiJjb2RGTFdLc1dMRmtYQldQNzZBZ25ucXlLcytCOGVGNGhhODd5bmJjUnVRPSJ9.",
      "app": "org1",
      "verb": "GET",
      "name": "TESTBEELD/example/browse.mp4",
      "useragent": "mpv 0.26.0",
      "client": "84.199.20.186",
      "expiration": "2017-07-26 13:53:27 +0200"
    }
  ]
}
```

## Usage

The ticket attributes can be given in a JSON formatted request body, as request uri
parameters or a combination of both.
If the `app` or the `name` attributes are missing from the request, they are
deduced from the certificate's first `O` attribute and the request uri respectively.

Access to the service requires a signed client certificate with a DC attribute `ticket`. The `O` attributes
of the subject restrict the mediafiles for which a ticket will be generated.
For example, the following certificate subject will allow to generate tokens for content owned by *org1*.
```
DC=ticket,O=org1,CN=John (jwt),emailAddress=john.thearchivist@example.org
```
Requests for content not owned by *org1* will invoke a HTTP 403 response.

(The code assumes that the client certificate is verified upstream, injecting the
certificate subject in a header.)
