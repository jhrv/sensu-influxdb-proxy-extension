sensu-influxdb-proxy-extension
==============================

Sensu extension for sending data to InfluxDB (ideally using the line protocol)
This extension uses the InfluxDB REST-API directly.

# Getting started

1) Add the *sensu-influxdb-proxy-extension.rb* to the sensu extensions folder (/etc/sensu/extensions)

2) Create your InfluxDB configuration for Sensu (or copy and edit *influxdb-proxy-extension.json.tmpl*) inside the sensu config folder (/etc/sensu/conf.d). 

```
{
    "influxdb-proxy-extension": {
        "hostname": "influxdb.mydomain.tld",
        "port": "8086",
        "database": "events",
        "username": "sensu",
        "password": "m3tr1c54l1f3"
    }
}
```

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

4) Send metrics from your application => socket @ localhost:3030

Send metrics directly from your applications using the TCP-socket the sensu-client exposes on port 3030. The output you write to the socket must be valid Sensu JSON as described [here](https://sensuapp.org/docs/latest/clients#client-socket-input)

Example payload:

```
{
   "name": "my_application_event",
   "output": "created_account,region=uswest value=1 1434055562000000000",
   "handler": ["events"],
   "status": 0
}
```

This will create the event "created_account" with the tag region=uswest and value 1 in InfluxDB. This can be anything that is valid to the [Line Protocol](https://influxdb.com/docs/v0.9/write_protocols/line.html)

5)  Restart your sensu-server and sensu-client(s)


If you follow the sensu-server log (/var/log/sensu/sensu-server.log) you should see the following output if all is working correctly:

```
{"timestamp":"2015-06-21T13:37:04.256753+0200","level":"info","message":"influxdb-extension:
Successfully initialized config: hostname: ....
```
