# Frequently asked questions

## `XPA.list()` or `XPA.find()` do not find my XPA server

In principle, XPA servers are able to automatically launch an XPA name-server for their type
of connection (internet or Unix socket) if none is running. If an XPA name-server is killed
or stop working, XPA servers registered by this name-server have to reconnect to another
name-server. In SAOImage/DS9 server, this can be done by using the menu `File > XPA >
Disconnect` and then `File > XPA > Connect`. If you have several SAOImage/DS9 servers, you
may have to do this with each server.
