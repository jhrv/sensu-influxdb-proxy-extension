sensu-influxdb-proxy-extension
========================

[Sensu](https://sensuapp.org/) extension for forwarding events to [InfluxDB](https://influxdb.com/). 

A common usecase for this extension is for the application to write data directly to the socket that the [Sensu-client](https://sensuapp.org/docs/latest/clients#client-socket-input) exposes whenever the event occurs, as opposed to collecting data on a regular time-interval (See [sensu-influxdb-extension](https://github.com/jhrv/sensu-influxdb-extension/) for that).

For each sensu-event it receives, it will assume that the output is on the [line protocol](https://influxdb.com/docs/v0.9/write_protocols/line.html) format. It will buffer up points until it reaches the configured length (see **buffer_size**), and then post the data directly to the InfluxDB REST-API.

# Getting started

1) Add the *sensu-influxdb-proxy-extension.rb* to the sensu extensions folder (/etc/sensu/extensions)

2) Create your InfluxDB configuration for Sensu (or copy and edit *influxdb-proxy-extension.json.tmpl*) inside the sensu config folder (/etc/sensu/conf.d). 

Example of a minimal configuration file
```
{
    "influxdb-proxy-extension": {
        "hostname": "influxdb.mydomain.tld",
        "database": "metrics",
    }
}
```

## Full list of configuration options

| variable          | default value         |
| ----------------- | --------------------- |
| hostname          |       none (required) |
| port              |                  8086 | 
| database          |       none (required) |
| buffer_size       |                   100 |
| ssl               |                 false |
| precision         |                 s (*) |
| retention_policy  |                  none |
| username          |                  none |
| password          |                  none |

(*) s = seconds. Other valid options are n, u, ms, m, h. See [influxdb docs](https://influxdb.com/docs/v0.9/write_protocols/write_syntax.html) for more details


3) Add the extension to your sensu-handler configuration 

```
"handlers": {
    "events": {
        "type": "set",
        "handlers": [ "influxdb-proxy-extension" ]        
    }
    ...
 }

```

4) Restart your sensu-server and sensu-client(s)


If you follow the sensu-server log (/var/log/sensu/sensu-server.log) you should see the following output if all is working correctly:

```
{"timestamp":"2015-06-21T13:37:04.256753+0200","level":"info","message":"influxdb-proxy-extension:
Successfully initialized config: hostname: ....
```

5) Now should now be able to write to the sensu-client socket, where the **output** is on the [line protocol](https://influxdb.com/docs/v0.9/write_protocols/line.html) format, and the **handler** is set to *events*.

#performance

The extension will buffer up points until it reaches the configured buffer_size length, and then post all the points in the buffer to InfluxDB. 
Depending on your load, you will want to tune the buffer_size configuration to match your environment.

Example:
If you set the buffer_size to 1000, and you have a event-frequency of 100 per second, it will give you about a ten second lag before the data is available through the InfluxDB query API.

buffer_size / event-frequency = latency

I recommend testing different buffer_sizes depending on your environment and requirements.
