# media-ticket-service

Media-ticket-service generates authentication
[tokens](https://github.com/viaacode/ticket) for third party access to VIAA
media content. The token is requested by atrusted application on behalf of a user.
It restricts access to a given named object based on clientip, user agent and time.

## Example

### Request

```bash
curl -X GET --key mycert.key --cert mycert.cert -d '{
  "app": "org1",
  "useragent": "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0",
  "verb": "GET",
  "client": "127.0.0.1"
  }' http://api.example.org/ticket/TESTBEELD/example/browse.mp4
```

### Response

```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJhdWQiOiJvcmcxIiwiZXhwIjoxNDk2MjI5NzYwLCJzaWciOiJXMTFNeFZjRkR1cC9IM29oamVadm52VTFYRURVUGN0QVM3d1JHK0RGWEJFPSJ9.",
  "context": {
    "app": "org1",
    "verb": "GET",
    "name": "TESTBEELD/example/browse.mp4",
    "useragent": "Mozilla/5.0 (X11; Linux x86_64; rv:10.0)
    Gecko/20100101 Firefox/10.0",
    "client": "127.0.0.1",
    "expiration": "2017-05-31 13:22:40 +0200"
  }
}

```
## Usage

The ticket attributes can be given in a JSON formatted request body or as request uri
parameters or a combination of both.
If the `app` or the `name` attributes are missing from the request, they are
deduced from the certificate's first `O` attribute or the request uri respectively.

Access to the service requires a signed client certificate. The `O` attributes
of the subject restrict the mediafiles for which a ticket will be generated. For
example:
```
DC=ticket,O=org1,CN=John (jwt),emailAddress=john.thearchivist@example.org
```

The client certificate is verified upstream, injecting the certificate subject 
in a header.
