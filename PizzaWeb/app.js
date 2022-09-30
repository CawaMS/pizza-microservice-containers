let appInsights = require("applicationinsights");
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .setSendLiveMetrics(false)
    .setDistributedTracingMode(appInsights.DistributedTracingModes.AI)
    .start();
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cons = require('consolidate');

var indexRouter = require('./routes/index');
var orderStatusRouter = require('./routes/orderStatus');

const axios = require('axios');

var app = express();

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// view engine setup
app.engine('html', cons.swig)
app.set('views', path.join(__dirname, 'public'));
app.set('view engine', 'html');

app.use('/', indexRouter);
app.use('/orderStatus', orderStatusRouter);

app.use(express.json({ type: ['application/json', 'application/*+json'] }));

// dapr integration
let DAPR_HOST = process.env.DAPR_HOST || "http://localhost";
const DAPR_HTTP_PORT = process.env.DAPR_HTTP_PORT || "3500";
let PUBSUBNAME = process.env.PUBSUBNAME || "pubsub";
let TOPICNAME = process.env.TOPICNAME || "order";
// publish endpoint: http://localhost:<daprPort>/v1.0/publish/<pubsubname>/<topic>[?<metadata>]
const pubsubEndpoint = `${DAPR_HOST}:${DAPR_HTTP_PORT}/v1.0/publish/${PUBSUBNAME}/${TOPICNAME}`;

let axiosConfig = {
    headers: {
        "dapr-app-id": "order-processor-http"
    }
  };

app.post('/submitOrder', function(req, res){
    axios.post(pubsubEndpoint, {
        "orderId": JSON.parse(req.body["orderID"]),
        "cart": JSON.parse(req.body["cart"]),
        "status": "created",
    })
        .then(function (response) {
            console.log("Submitted order : " + response.config.data);
        })
        .catch(function (error) {
            console.log("failed to publish message." + error);
        });
});

app.get('/getOrderStatus', function(req,res){
    console.log("invoked /getOrderStatus GET method");
    console.log("outputting the req order ID: "+ JSON.stringify(req.query["OrderID"]));
    var OrderID = req.query["OrderID"];
    axios.get(`${DAPR_HOST}:${DAPR_HTTP_PORT}/order/${OrderID}`, axiosConfig)
    .then(function(response){
        console.log("is response body null: ", response.body == null);
        console.log(`statusCode: ${response.status}`);
        console.log(response.data["status"]);
        res.send(response.data["status"])
    })
    .catch(function(error){
        console.log("failed to fetch for order status: "+error);
    })

});

module.exports = app;
