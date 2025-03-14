#
# cdefs.jl --
#
# Constants and structures defined in "xpa.h".  These "private" definitions are
# put in a sub-module to make them not directly accessible.
#
module CDefs

export XPACommRec, XPARec

#
# CONSTANTS
#

# Sizes.
const SZ_LINE = 4096
const XPA_NAMELEN = 1024

# This is the number of actual commands we have above
const XPA_CMDS = 4

#
# CALLBACK FUNCTIONS
#

# typedef int (*SendCb)(void *client_data, void *call_data, char *paramlist,
#                       char **buf, size_t *len);
struct SendCb end

# typedef int (*ReceiveCb)(void *client_data, void *call_data,
#                          char *paramlist, char *buf, size_t len );
struct ReceiveCb end

# typedef int (*InfoCb)(void *client_data, void *call_data,
#                       char *paramlist);
struct InfoCb end

# typedef void *(*SelAdd)(void *client_data, int fd);
abstract type SelAdd end

# typedef void (*SelDel)(void *client_data);
abstract type SelDel end

# typedef void (*SelOn)(void *client_data);
abstract type SelOn end

# typedef void  (*SelOff)(void *client_data);
abstract type SelOff end

# typedef void (*MyFree)(void *buf);
struct MyFree end

#
# OPAQUE STRUCTURES
#

# Opaque structure for `struct nsrec`.
abstract type NSRec end

# Opaque structure for `struct cliprec`.
abstract type ClipRec end

# Opaque structure for `struct xpainputrec`.
abstract type XPAInputRec end

# Opaque structure for `struct xpaclientrec`.
abstract type XPAClientRec end

# Opaque structure for `struct xpacmdrec`.
abstract type XPACmdRec end

#
# EXPORTED STRUCTURES
#

"""
    XPACommRec

XPA communication structure for each connection.
"""
struct XPACommRec
    next::Ptr{XPACommRec}
    status::Cint
    message::Cint
    n::Cint
    cmd::Cint
    mode::Cint
    telnet::Cint
    usebuf::Cint
    useacl::Cint
    id::Ptr{UInt8} # (C string)
    info::Ptr{UInt8} # (C string)
    target::Ptr{UInt8} # (C string)
    paramlist::Ptr{UInt8} # (C string)
    cmdfd::Cint
    datafd::Cint
    cendian::Ptr{UInt8} # (C string)
    ack::Cint
    # buf and len passed to callbacks
    buf::Ptr{UInt8} # (C string)
    len::Csize_t
    # for AF_INET
    cmdip::Cuint
    cmdport::Cint
    dataport::Cint
    # for AF_UNIX
    cmdname::Ptr{UInt8} # (C string)
    dataname::Ptr{UInt8} # (C string)
    acl::NTuple{XPA_CMDS+1,Cint}
    # for handling fd's in non-select event loops
    selcptr::Ptr{Cvoid} # cmdfd struct for seldel
    seldptr::Ptr{Cvoid} # datafd struct for seldel
    # pointer to associated name server
    ns::Ptr{NSRec}
    # myfree routine
    myfree::Ptr{MyFree}
    myfree_ptr::Ptr{Cvoid}
end

struct XPARec
    version::Ptr{UInt8} # xpa version string
    status::Cint        # status of this xpa
    type::Ptr{UInt8}    # (C string) "g", "s", "i" are server types; "c" for client
    #
    # THE SERVER SIDE
    #
    next::Ptr{XPARec}
    xclass::Ptr{UInt8} # (C string)
    name::Ptr{UInt8}   # (C string)
    help::Ptr{UInt8}   # (C string)
    # send callback info
    send_callback::Ptr{SendCb}
    send_data::Ptr{Cvoid}
    send_mode::Cint
    # receive callback info
    receive_callback::Ptr{ReceiveCb}
    receive_data::Ptr{Cvoid}
    receive_mode::Cint
    # info callback info
    info_callback::Ptr{InfoCb}
    info_data::Ptr{Cvoid}
    info_mode::Cint
    # list of sub-commands for this access point
    commands::Ptr{XPACmdRec}
    # communication info
    fd::Cint                      # listening socket file descriptor
    method::Ptr{UInt8}            # (C string) method string: host:ip or unix_filename
    nshead::Ptr{NSRec}            # name servers associated with this access point
    commhead::Ptr{XPACommRec}     # linked list of communcation records
    cliphead::Ptr{ClipRec}        # linked list of cliboard records
    filename::Ptr{UInt8}          # (C string) file name (unix sockets) for listening
    sendian::Ptr{UInt8}           # (C string) endian-ness of server
    # request-specific info
    comm::Ptr{XPACommRec}         # current comm if we are processing a request
    # select loop info
    seldel::Ptr{SelDel}           # routine to remove xpa socket from select loop
    seladd::Ptr{SelAdd}           # routine to add xpa command sockets to select loop
    selon ::Ptr{SelOn}            # routine to enable xpa command sockets
    seloff::Ptr{SelOff}           # routine to disable xpa command sockets
    selptr::Ptr{Cvoid}            # additional info for seldelete()
    #
    # THE CLIENT SIDE
    #
    persist::Cint                 # flag whether this is a persistent client
    nclient::Cint                 # number of clients -- used in processing headers
    client_mode::Cint             # global client mode
    clienthead::Ptr{XPAClientRec} # linked list of active clients
    ifd::Cint                     # input fd for XPASetFd()
    inpbytes::Csize_t             # total number of bytes in input lists
    inphead::Ptr{XPAInputRec}     # linked list of input structs
end

end # module
