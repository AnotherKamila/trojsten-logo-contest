cloudinary = require 'cloudinary'
express    = require 'express'
stylus     = require 'stylus'
url        = require 'url'
util       = require 'util'
fs         = require 'fs'

app = express()

app.use express.logger()
app.use express.bodyParser defer: true
app.use stylus.middleware src: __dirname+'/public'
app.use express.static __dirname+'/public'

app.set 'views', __dirname+'/templates'
app.set 'view engine', 'jade'

db = (require 'mongoskin').db process.env.MONGOHQ_URL, auto_reconnect: true, w: 'majority'
submits_c = db.collection 'submits'

app.get '/', (req, res) ->
    res.redirect '/submits'

app.get '/upload', (req, res) ->
    res.render 'uploadform', { action: '/' }

app.post '/', (req, res) ->
    req.form.on 'progress', (have, total) -> console.log ((have/total)*100).toFixed 2 + '% uploaded'
    req.form.on 'end', ->
        req.body.date = new Date()
        submits_c.insert req.body, { safe: true }, (err, records) ->
            # if err then TODO Error handling!
            console.log records

            onsuccess = (img_o) ->
                console.log img_o
                res.redirect "/submits/#{img_o.public_id}"

            cloudinary_stream = cloudinary.uploader.upload_stream onsuccess, public_id: records[0]._id.toString()
            fs.createReadStream(req.files.image.path, {encoding: 'binary'}).on('data', cloudinary_stream.write).on('end', cloudinary_stream.end)

app.get '/submits', (req, res) ->
    submits_c.find().toArray (err, result) ->
        console.error err if err?
        res.render 'submits', { cloudinary, submits: result }

app.get '/submits/:id', (req, res) ->
    submits_c.findOne _id: (db.ObjectID.createFromHexString req.params.id), (err, result) ->
        console.error err if err?
        res.render 'single_submit', { cloudinary, submit: result }

port = process.env.PORT || 5000
app.listen port
console.log "Listening on port #{port}"
