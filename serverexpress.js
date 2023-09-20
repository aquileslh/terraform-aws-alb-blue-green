const express = require('express');
const cors = require('cors')
const app = express()

app.use(cors())

app.get('/', (req, res) => {
    res.end(`Hello PID: ${process.pid}`);
});

app.get('/check', (req, res) => {
    console.log('Health Check Request');
    res.status(200).end();
});

app.listen(8080);
console.log(`Api Server running on ${process.env.PORT} port, PID: ${process.pid}`);