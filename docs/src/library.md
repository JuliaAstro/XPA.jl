# Reference

The following provides detailled documentation about types and methods provided
by the XPA package.  This information is also available from the REPL by typing
`?` followed by the name of a method or a type.


## XPA client methods and types

```@docs
XPA.Client
XPA.connection
XPA.get
XPA.Reply
XPA.get_data
XPA.get_server
XPA.get_message
XPA.has_error
XPA.has_errors
XPA.has_message
XPA.join_arguments
XPA.verify
XPA.set
XPA.buffer
```

## XPA server methods and types

```@docs
XPA.Server
XPA.SendCallback
XPA.store!
XPA.ReceiveCallback
XPA.peek
error(::XPA.Server,::AbstractString)
XPA.poll
XPA.message
XPA.mainloop
```


## Utilities

```@docs
XPA.address
XPA.list
XPA.AccessPoint
XPA.find
XPA.getconfig
XPA.setconfig!
```

## Constants

```@docs
XPA.SUCCESS
XPA.FAILURE
```
