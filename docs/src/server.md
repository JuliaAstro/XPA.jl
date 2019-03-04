# Implementing a server

## Create an XPA server

To create a new XPA server, call the [`XPA.Server`](@ref) method:

```julia
server = XPA.Server(class, name, help, send, recv)
```

where `class`, `name` and `help` are strings while `send` and `recv` are
callbacks created by the [`XPA.SendCallback`](@ref) and
[`XPA.ReceiveCallback`](@ref) methods:

```julia
send = XPA.SendCallback(sendfunc, senddata)
recv = XPA.ReceiveCallback(recvfunc, recvdata)
```

where `sendfunc` and `recvfunc` are the Julia methods to call while `senddata`
and `recvdata` are any data needed by the callback other than what is specified
by the client request (if omitted, `nothing` is assumed).  The callbacks
have the following forms:

```julia
function sendfunc(senddata, xpa::Server, params::String,
                  buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t})
    ...
    return XPA.SUCCESS
end
```

The callbacks must return an integer status (of type `Cint`): either
[`XPA.SUCCESS`](@ref) or [`XPA.FAILURE`](@ref).  The methods `XPA.seterror()`
and `XPA.setmessage()` can be used to specify a message accompanying the
result.


```julia
XPA.store!(...)
XPA.get_send_mode(xpa)
XPA.get_recv_mode(xpa)
XPA.get_name(xpa)
XPA.get_class(xpa)
XPA.get_method(xpa)
XPA.get_sendian(xpa)
XPA.get_cmdfd(xpa)
XPA.get_datafd(xpa)
XPA.get_ack(xpa)
XPA.get_status(xpa)
XPA.get_cendian(xpa)
```


## Manage XPA requests


```julia
XPA.poll(msec, maxreq)
```

or

```julia
XPA.mainloop()
```
