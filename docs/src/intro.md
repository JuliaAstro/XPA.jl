# Using the XPA messaging system

In your Julia code/session, it is sufficient to do:

```julia
import XPA
```

or:

```julia
using XPA
```

This makes no differences as nothing is exported by the `XPA` module. This means that all
methods or constants are prefixed by `XPA.`; but you may change the suffix, for instance:

```julia
import XPA as xpa
```

or in Julia version 1.5 or older:

```julia
using XPA
const xpa = XPA
```

The implemented methods are described in what follows, first the client side, then the
server side and finally some utilities. More extensive XPA documentation can be found
[here](http://hea-www.harvard.edu/RD/xpa/help.html).
