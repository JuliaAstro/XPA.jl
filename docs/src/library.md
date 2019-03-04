# Reference

The following provides detailled documentation about types and methods provided
by the XPA package.  This information is also available from the REPL by typing
`?` followed by the name of a method or a type.


## XPA client methods and types

```@docs
XPA.Client
```
```@docs
XPA.get
```
```@docs
XPA.Reply
```
```@docs
XPA.get_data
```
```@docs
XPA.get_server
```
```@docs
XPA.get_message
```
```@docs
XPA.has_error
```
```@docs
XPA.has_errors
```
```@docs
XPA.has_message
```
```@docs
XPA.verify
```
```@docs
XPA.set
```
```@docs
XPA.buffer
```

## XPA server methods and types

```@docs
XPA.Server
```
```@docs
XPA.SendCallback
```
```@docs
XPA.store!
```
```@docs
XPA.ReceiveCallback
```
```@docs
XPA.peek
```
```@docs
error(::XPA.Server,::AbstractString)
```
```@docs
XPA.poll
```
```@docs
XPA.message
```
```@docs
XPA.mainloop
```


## Utilities

```@docs
XPA.list
```
```@docs
XPA.AccessPoint
```
```@docs
XPA.find
```
```@docs
XPA.getconfig
```
```@docs
XPA.setconfig!
```


## Constants
```@docs
XPA.SUCCESS
XPA.FAILURE
```
