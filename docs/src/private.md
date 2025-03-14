# Private methods

This page documents the internal methods for XPA.jl developers. Since these are
not part of the public API, the page is hidden from the site navigation.

!!! warning
    The functions documented here are internal to XPA.jl and should not be
    considered of the stable/public API.

## Types

```@docs
XPA.Buffer
XPA.SendBuffer
XPA.ReceiveBuffer
XPA.NullBuffer

XPA.Handle
XPA.Callback

XPA.TupleOf
```

## Functions

```@docs
XPA._override_nsusers
XPA._restore_nsusers
XPA._nmax
XPA._get_buf
XPA._memcpy!
XPA._free
XPA._malloc
XPA._get_field
XPA._open
close
```

## `XPA.CDefs` module

```@docs
XPA.CDefs.SelOn
XPA.CDefs.SelOff
XPA.CDefs.SelAdd
XPA.CDefs.SelDel
XPA.CDefs.SendCb
XPA.CDefs.ReceiveCb
XPA.CDefs.MyFree
XPA.CDefs.InfoCb

XPA.CDefs.XPARec
XPA.CDefs.XPACommRec
XPA.CDefs.NSRec
XPA.CDefs.ClipRec
XPA.CDefs.XPAInputRec
XPA.CDefs.XPAClientRec
XPA.CDefs.XPACmdRec
```
