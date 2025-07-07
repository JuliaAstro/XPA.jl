# Private methods

This page documents the internal methods for `XPA.jl` developers. Since these are not part
of the public API, the page is hidden from the site navigation.

!!! warning
    The functions documented here are internal to `XPA.jl` and should not be considered as
    being part of the stable/public API.

## Types

```@docs
XPA.SendBuffer
XPA.ReceiveBuffer
XPA.NullBuffer
XPA.TupleOf
```

## Functions

```@docs
XPA._override_nsusers
XPA._restore_nsusers
```

## `XPA.CDefs` module

```@docs
XPA.CDefs
XPA.CDefs.SelOn
XPA.CDefs.SelOff
XPA.CDefs.SelAdd
XPA.CDefs.SelDel
XPA.CDefs.SendCb
XPA.CDefs.ReceiveCb
XPA.CDefs.MyFree
XPA.CDefs.InfoCb

XPA.CDefs.XPACommRec
XPA.CDefs.NSRec
XPA.CDefs.ClipRec
XPA.CDefs.XPAInputRec
XPA.CDefs.XPAClientRec
XPA.CDefs.XPACmdRec
```
