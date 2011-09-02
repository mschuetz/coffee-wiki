Http = require 'http'
Url = require 'url'
Mongolian = require 'mongolian'
Assert = require 'assert'
Mu = require 'Mu'
Mu.templateRoot = './html'
fs = require 'fs'
markdown = require('markdown').markdown

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
  
serveEditor = (page, httpResponse) ->
  pages.findOne title: page.title,
    (err, page) ->
      if err 
        console.log err
        httpResponse.writeHead 500,
          'Content-type': 'text/plain'
        httpResponse.end err
      else 
        status = (200 if page) or 404
        httpResponse.writeHead status, 'Content-type': 'text/html; charset=utf-8'
        render 'editor.html', {title: page.title, content: (page.content if page)}, httpResponse

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
        httpResponse.writeHead 200, 'Content-type': 'text/html; charset=utf-8'
        render 'page.html',
          {title: pagename, content: () ->
            markdown.toHTML(page.content)
          }, httpResponse
      else
        serveEditor {title: pagename, content: ''}, httpResponse

serveErrorPage = (httpResponse, status, message) ->
  httpResponse.writeHead status, 'Content-type': 'text/plain'
  httpResponse.end 'internal error'

savePage = (pagename, httpRequest, httpResponse) ->
  content = ""
  httpRequest.on 'data', (buffer) ->
    content += buffer
  httpRequest.on 'end', () ->
    console.log content
    match = content.match('^content=(.+)$')
    if match
      pagecontent = decodeURIComponent(match[1].replace(/\+/g, ' ')) 
      pages.findAndModify {query: {title: pagename}, update : {title: pagename, content: pagecontent}, upsert: true}, (err, doc) ->
        if err
          console.log err
          serveErrorPage(500, 'error while updating page')
        # TODO: serve using result of modify
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

parseRequestUrl = (url) ->
  path = Url.parse(url).pathname
  Assert.equal path[0], '/'
  if path.length == 1
    return null
    
  components = path.split('/')
  {page: decodeURI(components[1]), action: (decodeURI(components[2]) if components[2])}

server = Http.createServer (req, res) ->
  action = parseRequestUrl req.url
  console.log req.method + " request on " + req.url
  console.log "action=" + JSON.stringify(action)
  switch (req.method)
    when 'GET'
      if action
        if match = action.page.match('^__css__$')
          serveStatic 'css', 'text/css', res
        else
          if (action.action == 'edit')
            serveEditor {title: action.page, content: ''}, res
          else
            servePage action.page, res
      else
        serveIndex(res)
    when 'POST'
      if action and action.page
        savePage(action.page, req, res)
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
