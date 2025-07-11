# Changes in XPA package

## Version 0.3.0 (2025-07-09)

This version fixes some bugs and introduces a better API to deal with XPA reply which is now
implemented as a vector of answer(s) with properties to retrieve their status, associated
message, and data. Code using the previous version should run almost unchanged except for
the `preserve` keyword in `XPA.get_data` that has been replaced by `take`.

### Added

- Use `@public` macro from [`TypeUtils`](https://github.com/emmt/TypeUtils.jl) package to
  declare non-exported public methods.

- Methods `XPA.preserve_state` and `XPA.restore_state` to preserve or save and restore the
  state of a dictionary for a given key.

### Fixed

- Client and server objects are preserved from being garbage collected in `ccall`,
  `unsafe_load`, and `unsafe_store!`.

- `XPA.connection()` now returns a per-task client connection which is automatically re-open
  if accidentally closed, and which is eventually closed when the task is garbage collected.
  Previously, a per-thread client connection was returned which was wrong because a given
  Julia task may migrate to another thread.

- `XPA.getconfig` and `XPA.setconfig` have been fixed fixed and their type stability
  improved.

### Changed

- `XPA.list` uses `xpaget` executable by default to allow for specifying the connection
  method (`inet`, `unix`, `local`, or `localhost`) with the XPA server.

- `XPA.list` can be called with a predicate function to filter the servers based on their
  `XPA.AccessPoint`: `XPA.list(f)` is the same as `filter(f, XPA.list()))`.

- `XPA.find` can also be called with a predicate function and may interact with the user to
  select a single access-point. This later idea came from (Marco
  Lombardi)[https://github.com/astrozot], many thanks to him.

- Previous methods for `XPA.list` and `XPA.find` have been deprecated.

- Reply object `rep` returned by `XPA.get` is now an abstract vector of answers. The syntax
  `rep[]` yields `rep[1]` if `rep` has a single answer and throws otherwise. An answer
  `rep[i]` has properties that replace the need to call accessors, these properties are
  listed in the following table.

  | New syntax with properties      | Old syntax with accessors                |
  |:--------------------------------|:-----------------------------------------|
  | `rep[i].server`                 | `XPA.get_server(rep, i)`                 |
  | `rep[i].message`                | `XPA.get_message(rep, i)`                |
  | `rep[i].has_error`              | `XPA.has_error(rep, i)`                  |
  | `rep[i].has_message`            | `XPA.has_message(rep, i)`                |
  | `rep[i].data(args...; kwds...)` | `XPA.get_data(args..., rep, i; kwds...)` |

- The `perserve` keyword of the `XPA.get_data` method and the `data` properties of XPA
  answers has been replaced by the `take` keyword with opposite meaning and slightly
  different semantic (it is ignored if stealing the internal buffer does not save memory).

- Properties of `apt::XPA.AccessPoint` are the recommended way to retrieve the content of
  `apt`. For example, use `apt.address` instead of `XPA.address(apt)`. Method `isopen(apt)`
  yields whether the address in `apt` is a non-empty string.

- `XPA.AccessPoint` has a constructor that takes all members specified by keywords.

- Constructors for `XPA.AccessPoint` accept `access` as a string composed of characters
  `'g'`, `'s'`, and `'i'` respectively indicating whether `get`, `set`, and `info` commands
  are implemented by the server.

- `XPA.AccessPoint(str)`, `parse(XPA.AccessPoint, str)`, and `tryparse(XPA.AccessPoint,
  str)` can be used to convert a string `str` to an XPA access-point assuming the same
  format as the output of `xpans`.

- Private abstract type `XPA.Handle` removed. Use `Union{XPA.Client,XPA.Server}` instead.


## Version 0.2.2

- Remove unused type parameter. Stop newer julia from complaining.

## Version 0.2.1

- Fix typo in function name.
- Rename `xpa` variables as `conn` for clarity.
- Fix issue with `NULL` data buffer.

## Version 0.2.0

### New functionalities and improvements

- To avoid the delay for connecting to the XPA server, all XPA methods that
  perform XPA client requests now automatically use a connection that is kept
  open for the calling thread.  Directly calling `XPA.Client()` should be no
  longer necessary.

  ```julia
  julia> using XPA, BenchmarkTools
  julia> conn = XPA.Client() # create a persistent client connection
  julia> temp = XPA.Client(C_NULL) # to force a new connection for each request
  julia> @btime XPA.get($temp, "DS9:ds9", "version");
    352.447 μs (3 allocations: 240 bytes)
  julia> @btime XPA.get($conn, "DS9:ds9", "version");
    222.088 μs (3 allocations: 240 bytes)
  julia> @btime XPA.get(       "DS9:ds9", "version");
    188.957 μs (3 allocations: 240 bytes)
  ```


## Version 0.1.0

### New functionalities and improvements

- `XPA.jl` now dependends on `XPA_jll` artifact to provide the XPA dynamic
  library.  This requires Julia version ≥ 1.3.

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
