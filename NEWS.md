# Changes in XPA package

## Version 0.1.0

### New functionalities and improvements

- New method `XPA.find` to retrieve the address of a specific server.

- New method `XPA.address` to get the address of an XPA accesspoint specified
  in various forms.

- New `XPA.verify` method to check whether a result from an XPA request has
  errors.

- Many changes for the management of send/receive buffers:

  - New method `XPA.peek` to query the contents of the accompanying data in a
    receive callback.  Returned array can be a temporary one.

  - Method `XPA.store!` replaces `XPA.setbuffer!` to set the contents of the
    accompanying data in a send callback.

  - The only remaining option in send/receive callback is `acl` to enable
    access control.  Other options (related to allocate/copy/delete data) are
    set so as to avoid memory leaks and access unavailable memory.  This is
    perhaps to the detriment of performances.

- New types `SendBuffer` and `ReceiveBuffer` to simplify the writing of callbacks.

- Send/receive mode types can be retrieved.

- Bug fixes.

- Some fixes in scripts for MacOS.


### Changes of behavior

- Keyword `check` has been replaced by `throwerrors` in `XPA.get`.

- Change the type of result returned by `XPA.get` and `XPA.set`:

  `XPA.get` and `XPA.set` now return an instance of `Reply`.  Methods are
  provided to deal with such instances and to retrieve the contents (name of
  server, message or data) of a given reply in various forms.  Instances of
  `Reply` are mutable object and have a finalizer which takes care of correctly
  freeing memory.  By default, when retrieving the data associated with a given
  reply, the ownership of the data is transfered to Julia thus avoiding
  unecessary copies.

  Old `XPA.get_*` methods have been suppressed as the same result can be
  obtained by spcifying the type of result in calls to `XPA.get` or to the new
  `XPA.get_data`.

- Specialize `SendCallback` and `ReceiveCallback`: they are now mutable
  structures and the callback function type is now part of their signature.

- Method `setbuf!` renamed as `setbuffer!`.
