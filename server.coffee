Http = require 'http'
Url = require 'url'
Mongolian = require 'mongolian'
Assert = require 'assert'
Mu = require 'Mu'
Mu.templateRoot = './html'
fs = require 'fs'

uri = process.env.MONGOHQ_URL or "mongo://localhost/org"
# workaround because current release of mongolian cannot parse mongodb:// urls
uri = uri.replace('mongodb://', 'mongo://')
pages = new Mongolian(uri).collection("pages")

render = (template, ctx, httpResponse) ->
  Mu.render template, ctx, {}, (err, out) ->
    if err
      throw err
    buffer = ''
    out.addListener 'data', (data) ->
      httpResponse.write data
    out.addListener 'end', () ->
      httpResponse.end()
  
serveNewEditor = (pagename, httpResponse) ->
  httpResponse.writeHead 404,
    'Content-type': 'text/html'
  render 'editor.html', {title: pagename}, httpResponse

servePage = (pagename, httpResponse) ->
  pages.findOne title: pagename,
    (err, page) ->
      if err 
        console.log err
        httpResponse.writeHead 500,
          'Content-type': 'text/plain'
        httpResponse.end err
      else if page
        console.log 'serving page ' + pagename
        httpResponse.writeHead 200,
          'Content-type': 'text/plain; charset=utf-8'
        httpResponse.end page.content
      else
        serveNewEditor pagename, httpResponse

savePage = (pagename, httpRequest, httpResponse) ->
  content = ""
  httpRequest.on 'data', (buffer) ->
    content += buffer
  httpRequest.on 'end', () ->
    console.log content
    match = content.match('^content=(.+)$')
    if match
      pages.insert {title: pagename, content: decodeURIComponent(match[1].replace(/\+/g, ' '))} 
      servePage(pagename, httpResponse)
    else
      httpResponse.end 'please provide some content'

serveIndex = (httpResponse) ->
  console.log 'would serve index'
  httpResponse.end()

serveStatic = (file, contentType, httpResponse) ->
  console.log "serving static file " + file
  fs.readFile './static/' + file, (err, content) ->
    httpResponse.writeHead 200,
      'Content-type': contentType
    httpResponse.end content

getPageName = (url) ->
  path = Url.parse(url).pathname
  Assert.equal path[0], '/'
  if path.length == 1
    return null
  match = path.match '^/(.+)'
  decodeURI(match[1])

server = Http.createServer (req, res) ->
  pagename = getPageName req.url
  console.log req.method + " request on " + req.url 
  switch (req.method)
    when 'GET'
      if pagename
        console.log pagename
        if match = pagename.match('^__css__$')
          serveStatic 'css', 'text/css', res
        else
          servePage pagename, res
      else
        serveIndex(httpResponse)
    when 'POST'
      if pagename
        savePage(pagename, req, res)
      else
        console.log 'a POST to nowhere'
    else
      console.log 'unhandled request'
      httpResponse.writeHead 404,
        'Content-type': 'text/plain'
      httpResponse.end 'nil.'        

port = process.env.PORT or 3000
console.log 'binding port ' + port
server.listen port 
