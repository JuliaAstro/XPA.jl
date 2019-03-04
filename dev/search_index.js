var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "The XPA.jl package",
    "title": "The XPA.jl package",
    "category": "page",
    "text": ""
},

{
    "location": "#The-XPA.jl-package-1",
    "page": "The XPA.jl package",
    "title": "The XPA.jl package",
    "category": "section",
    "text": "XPA Messaging System provides seamless communication between many kinds of Unix/Windows programs, including X programs, Tcl/Tk programs or some popular astronomical tools such as SAOImage-DS9.XPA.jl provides a Julia interface to the XPA messaging system.  XPA.jl can be used to send data ro commands to XPA servers or to query data from XPA servers.  XPA.jl can also be used to implement an XPA server. The package exploits the power of ccall to directly call the routines of the compiled XPA library."
},

{
    "location": "#Table-of-contents-1",
    "page": "The XPA.jl package",
    "title": "Table of contents",
    "category": "section",
    "text": "Pages = [\"intro.md\", \"client.md\", \"install.md\", \"misc.md\", \"server.md\",\n         \"library.md\"]"
},

{
    "location": "#Index-1",
    "page": "The XPA.jl package",
    "title": "Index",
    "category": "section",
    "text": ""
},

{
    "location": "install/#",
    "page": "Installation",
    "title": "Installation",
    "category": "page",
    "text": ""
},

{
    "location": "install/#Installation-1",
    "page": "Installation",
    "title": "Installation",
    "category": "section",
    "text": "To use XPA.jl package, XPA dynamic library and header files must be installed on your computer.  If this is not the case, they may be available for your operating system.  Otherwise, you\'ll have to build it and install it yourself. Depending on this condition, there are two possibilities described below.The source code of XPA.jl is available here."
},

{
    "location": "install/#Easy-installation-1",
    "page": "Installation",
    "title": "Easy installation",
    "category": "section",
    "text": "The easiest installation is when your system provides XPA dynamic library and header files as a package.  For example, on Ubuntu, just do:sudo apt-get install xpa-tools libxpa-devThen, to install XPA.jl package from Julia, just do:using Pkg\nPkg.add(\"XPA\")"
},

{
    "location": "install/#Custom-installation-1",
    "page": "Installation",
    "title": "Custom installation",
    "category": "section",
    "text": "If XPA dynamic library and header files are not provided by your system, you may install it manually.  That\'s easy but make sure that you compile and install the shared library of XPA since this is the one that will be used by Julia.  You have to download the source archive here, unpack it in some directory, build and install it.  For instance:cd \"$SRCDIR\"\nwget -O xpa-2.1.18.tar.gz https://github.com/ericmandel/xpa/archive/v2.1.18.tar.gz\ntar -zxvf xpa-2.1.18.tar.gz\ncd xpa-2.1.18\n./configure --prefix=\"$PREFIX\" --enable-shared\nmkdir -p \"$PREFIX/lib\" \"$PREFIX/include\" \"$PREFIX/bin\"\nmake installwhere $SRCDIR is the directory where to download the archive and extract the source while $PREFIX is the directory where to install XPA library, header file(s) and executables.  You may consider other configuration options (run ./configure --help for a list) but make sure to have --enable-shared for building the shared library.  As of the current version of XPA (2.1.18), the installation script does not automatically build some destination directories, hence the mkdir -p ... command above.In order to use XPA.jl with a custom XPA installation, you may define the environment variables XPA_DEFS and XPA_LIBS to suitable values before building XPA package.  The environment variable XPA_DEFS specifies the C-preprocessor flags for finding the headers \"xpa.h\" and \"prsetup.h\" while the environment variable XPA_LIBS specifies the linker flags for linking with the XPA dynamic library.  If you have installed XPA as explained above, do:export XPA_DEFS=\"-I$PREFIX/include\"\nexport XPA_LIBS=\"-L$PREFIX/lib -lxpa\"It may also be the case that you want to use a specific XPA dynamic library even though your system provides one.  Then define the environment variable XPA_DEFS as explained above and define the environment variable XPA_DLL with the full path to the dynamic library to use.  For instance:export XPA_DEFS=\"-I$PREFIX/include\"\nexport XPA_DLL=\"$PREFIX/lib/libxpa.so\"Note that if both XPA_LIBS and XPA_DLL are defined, the latter has precedence.These variables must be defined before launching Julia and cloning/building the XPA package.  You may also add the following lines in ~/.julia/config/startup.jl:ENV[\"XPA_DEFS\"] = \"-I/InstallDir/include\"\nENV[\"XPA_LIBS\"] = \"-L/InstallDir/lib -lxpa\"or (depending on the situation):ENV[\"XPA_DEFS\"] = \"-I/InstallDir/include\"\nENV[\"XPA_DLL\"] = \"/InstallDir/lib/libxpa.so\"where InstallDir should be modified according to your specific installation."
},

{
    "location": "intro/#",
    "page": "Using the XPA messaging system",
    "title": "Using the XPA messaging system",
    "category": "page",
    "text": ""
},

{
    "location": "intro/#Using-the-XPA-messaging-system-1",
    "page": "Using the XPA messaging system",
    "title": "Using the XPA messaging system",
    "category": "section",
    "text": "In your Julia code/session, it is sufficient to do:import XPAor:using XPAThis makes almost no differences as nothing, but XPA_VERSION (the version of the XPA dynamic library), is exported by the XPA module.  This means that all methods or constants are prefixed by XPA..  You may change the suffix, for instance:using XPA\nconst xpa = XPAThe implemented methods are described in what follows, first the client side, then the server side and finally some utilities.  More extensive XPA documentation can be found here."
},

{
    "location": "client/#",
    "page": "Client operations",
    "title": "Client operations",
    "category": "page",
    "text": ""
},

{
    "location": "client/#Client-operations-1",
    "page": "Client operations",
    "title": "Client operations",
    "category": "section",
    "text": "Client operations involve querying data from one or several XPA servers or sending data to one or several XPA servers."
},

{
    "location": "client/#Persistent-client-connection-1",
    "page": "Client operations",
    "title": "Persistent client connection",
    "category": "section",
    "text": "For each client request, XPA is able to automatically establish a temporary connection to the server.  This however implies some overheads and, to speed up the connection, a persistent XPA client can be created by calling XPA.Client() which returns an opaque object.  The connection is automatically shutdown and related resources freed when the client object is garbage collected.  The close() method can also by applied to the client object, in that case all subsequent requests with the object will establish a (slow) temporary connection."
},

{
    "location": "client/#Getting-data-from-one-or-more-servers-1",
    "page": "Client operations",
    "title": "Getting data from one or more servers",
    "category": "section",
    "text": ""
},

{
    "location": "client/#Available-methods-1",
    "page": "Client operations",
    "title": "Available methods",
    "category": "section",
    "text": "To query something from one or more XPA servers, call XPA.get method:XPA.get([xpa,] apt, args...) -> repwhich uses the client connection xpa to retrieve data from one or more XPA access points identified by apt as a result of the command build from arguments args....  Argument xpa is optional, if it is not specified, a (slow) temporary connection is established.  The XPA access point apt is a string which can be a template name, a host:port string or the name of a Unix socket file.  The utility XPA.list() can be called to list available servers.  The arguments args... are automatically converted into a single command string where the arguments are separated by a single space.For instance:julia> XPA.list()\n1-element Array{XPA.AccessPoint,1}:\n XPA.AccessPoint(\"DS9\", \"ds9\", \"7f000001:44805\", \"eric\", 0x0000000000000003)indicates that a single XPA server is available and that it is SAOImage-DS9, an astronomical tool to display images.  The server name is DS9:ds9 which can be matched by the template DS9:*, its address is 7f000001:44805. Either of these strings can be used to identify this server but only the address is unique.  Indeed there may be more than one server with class DS9 and name ds9.To query the version number of SAOImage-DS9, we can do:rep = XPA.get(\"DS9:*\", \"version\");For best performances, we can do the following:ds9 = (XPA.Client(), \"7f000001:44805\");\nrep = XPA.get(ds9..., \"version\");and use ds9... in all calls to XPA.get or XPA.set (described later) to use a fast client connection to the uniquely identified SAOImage-DS9 server.The answer, say rep, to the XPA.get request is an instance of XPA.Reply.  Various methods are available to retrieve information or data from rep.  For instance, length(rep) yields the number of answers which may be zero if no servers have answered the request (the maximum number of answers can be specified via the nmax keyword of XPA.get; by default, nmax=1 to retrieve at most one answer).There may be errors or messages associated with the answers.  The check whether the i-th answer has an associated error message, call the XPA.has_error method:XPA.has_error(rep, i=1) -> booleannote: Note\nHere and in all methods related to a specific answer in a reply to XPA.get or XPA.set requests, the answer index i can be any integer value.  If it is not such that 1 ≤ i ≤ length(rep), it is assumed that there is no corresponding answer and an empty (or false) result is returned.  By default, the first answer is always assumed (as if i=1).To check whether there are any errors, call the XPA.has_errors method:XPA.has_errors(rep) -> booleanTo avoid checking for errors for every answer to all requests, the XPA.get method has a check keyword that can be set true in order to automatically throw an exception if there are any errors in the answers.The check whether the i-th answer has an associated message, call the XPA.has_message method:XPA.has_message(rep, i=1) -> booleanTo retrieve the message (perhaps an error message), call the XPA.get_message method:XPA.get_message(rep, i=1) -> stringwhich yields a string, possibly empty if there are no associated message with the i-th answer in rep or if i is out of range.To retrieve the identity of the server which answered the request, call the XPA.get_server method:XPA.get_server(rep, i=1) -> stringUsually the most interesting part of a particular answer is its data part which can be extracted with the XPA.get_data method.  The general syntax to retrieve the data associated with the i-th answer in rep is:XPA.get_data([T, [dims,]], rep, i=1; preserve=false) -> datawhere optional arguments T (a type) and dims (a list of dimensions) may be used to specify how to interpret the data.  If they are not specified, a vector of bytes (Vector{UInt8}) is returned.note: Note\nFor efficiency reason, copying the associated data is avoided if possible. This means that a call to XPA.get_data can steal the data and subsequent calls will behave as if the data part of the answer is empty. To avoid this (and force copying the data), use keyword preserve=true in calls to XPA.get_data.  Data are always preserved when a String is extracted from the associated data.Assuming rep is the result of some XPA.get or XPA.set request, the following lines of pseudo-code illustrate the roles of the optional T and dims arguments:XPA.get_data(rep, i=1; preserve=false) -> buf::Vector{UInt8}\nXPA.get_data(String, rep, i=1; preserve=false) -> str::String\nXPA.get_data(Vector{S}, [len,] rep, i=1; preserve=false) -> vec::Vector{S}\nXPA.get_data(Array{S}, (dim1, ..., dimN), rep, i=1; preserve=false) -> arr::Array{S,N}\nXPA.get_data(Array{S,N}, (dim1, ..., dimN), rep, i=1; preserve=false) -> arr::Array{S,N}here buf is a vector of bytes, str is a string, vec is a vector of len elements of type S (if len is unspecified, the length of the vector is the maximum possible given the actual size of the associated data) and arr is an N-dimensional array whose element type is S and dimensions dim1, ..., dimN.If you are only interested in the data associated to a single answer, you may directly specify arguments T and dims in the XPA.get call:XPA.get(String, [xpa,] apt, args...) -> str::String\nXPA.get(Vector{S}, [len,] [xpa,] apt, args...) -> vec::Vector{S}\nXPA.get(Array{S}, (dim1, ..., dimN), [xpa,] apt, args...) -> arr::Array{S,N}\nXPA.get_data(Array{S,N}, (dim1, ..., dimN), [xpa,] apt, args...) -> arr::Array{S,N}In that case, exactly one answer and no errors are expected from the request (as if nmax=1 and check=true were specified)."
},

{
    "location": "client/#Examples-1",
    "page": "Client operations",
    "title": "Examples",
    "category": "section",
    "text": "The following examples assume that you have created an XPA client connection and identified the address of a SAOImage-DS9 server.  For instance:using XPA\nconn = XPA.Client()\naddr = split(XPA.get_server(XPA.get(conn, \"DS9:*\", \"version\"; nmax=1, check=true)); keepempty=false)[2]\nds9 = (conn, addr)To retrieve the version as a string:julia> XPA.get(String, ds9..., \"version\")\n\"ds9 8.0.1\\n\"To split the answer in (non-empty) words:split(XPA.get(String, ds9..., \"version\"); keepempty=false)You may use keyword keepempty=true in split(...) to keep empty strings in the result.To retrieve the answer as (non-empty) lines:split(XPA.get(String, ds9..., \"about\"), r\"\\n|\\r\\n?\"; keepempty=false)To retrieve the dimensions of the current image:map(s -> parse(Int, s), split(XPA.get(String, ds9..., \"fits size\"); keepempty=false))"
},

{
    "location": "client/#Sending-data-to-one-or-more-servers-1",
    "page": "Client operations",
    "title": "Sending data to one or more servers",
    "category": "section",
    "text": "The XPA.set method is called to send a command and some optional data to a server.  The general syntax is:XPA.set([xpa,] apt, args...; data=nothing) -> repwhich sends data to one or more XPA access points identified by apt with arguments args... (automatically converted into a single string where the arguments are separated by a single space).  As with XPA.get, the result is an instance of XPA.Reply.  See the documentation of XPA.get for explanations about how to manipulate such a result.The XPA.set method accepts the same keywords as XPA.get plus the data keyword used to specify the data to send to the server(s).  Its value may be nothing, an array or a string.  If it is an array, it must have contiguous elements (as a for a dense array) and must implement the pointer method.  By default, data=nothing which means that no data are sent to the server(s), just the command string made of the arguments args...."
},

{
    "location": "client/#Messages-1",
    "page": "Client operations",
    "title": "Messages",
    "category": "section",
    "text": "The returned messages string are of the form:XPA$ERROR message (class:name ip:port)orXPA$MESSAGE message (class:name ip:port)depending whether an error or an informative message has been set (with XPA.error() or XPA.message() respectively).  Note that when there is an error stored in an messages entry, the corresponding data buffers may or may not be empty, depending on the particularities of the server."
},

{
    "location": "server/#",
    "page": "Implementing a server",
    "title": "Implementing a server",
    "category": "page",
    "text": ""
},

{
    "location": "server/#Implementing-a-server-1",
    "page": "Implementing a server",
    "title": "Implementing a server",
    "category": "section",
    "text": ""
},

{
    "location": "server/#Create-an-XPA-server-1",
    "page": "Implementing a server",
    "title": "Create an XPA server",
    "category": "section",
    "text": "To create a new XPA server, call the XPA.Server method:server = XPA.Server(class, name, help, send, recv)where class, name and help are strings while send and recv are callbacks created by the XPA.SendCallback and XPA.ReceiveCallback methods:send = XPA.SendCallback(sendfunc, senddata)\nrecv = XPA.ReceiveCallback(recvfunc, recvdata)where sendfunc and recvfunc are the Julia methods to call while senddata and recvdata are any data needed by the callback other than what is specified by the client request (if omitted, nothing is assumed).  The callbacks have the following forms:function sendfunc(senddata, xpa::Server, params::String,\n                  buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t})\n    ...\n    return XPA.SUCCESS\nendThe callbacks must return an integer status (of type Cint): either XPA.SUCCESS or XPA.FAILURE.  The methods XPA.seterror() and XPA.setmessage() can be used to specify a message accompanying the result.XPA.setbuffer!(...)\nXPA.get_send_mode(xpa)\nXPA.get_recv_mode(xpa)\nXPA.get_name(xpa)\nXPA.get_class(xpa)\nXPA.get_method(xpa)\nXPA.get_sendian(xpa)\nXPA.get_cmdfd(xpa)\nXPA.get_datafd(xpa)\nXPA.get_ack(xpa)\nXPA.get_status(xpa)\nXPA.get_cendian(xpa)"
},

{
    "location": "server/#Manage-XPA-requests-1",
    "page": "Implementing a server",
    "title": "Manage XPA requests",
    "category": "section",
    "text": "XPA.poll(msec, maxreq)orXPA.mainloop()"
},

{
    "location": "misc/#",
    "page": "Utilities",
    "title": "Utilities",
    "category": "page",
    "text": ""
},

{
    "location": "misc/#Utilities-1",
    "page": "Utilities",
    "title": "Utilities",
    "category": "section",
    "text": "The method:XPA.list([xpa]) -> arrreturns a list of the existing XPA access points as an array of structured elements of type XPA.AccessPoint such that:arr[i].class    # class of the access point\narr[i].name     # name of the access point\narr[i].addr     # socket address\narr[i].user     # user name of access point owner\narr[i].access   # allowed access (g=xpaget,s=xpaset,i=xpainfo)all fields but access are strings, the addr field is the name of the socket used for the connection (either host:port for internet socket, or a file path for local unix socket), access is a combination of the bits XPA.GET, XPA.SET and/or XPA.INFO depending whether XPA.get(), XPA.set() and/or XPA.info() access are granted.  Note that XPA.info() is not yet implemented.XPA messaging system can be configured via environment variables.  The methods XPA.getconfig and XPA.setconfig! provides means to get or set XPA settings:XPA.getconfig(key) -> valyields the current value of the XPA parameter key which is one of:\"XPA_MAXHOSTS\"\n\"XPA_SHORT_TIMEOUT\"\n\"XPA_LONG_TIMEOUT\"\n\"XPA_CONNECT_TIMEOUT\"\n\"XPA_TMPDIR\"\n\"XPA_VERBOSITY\"\n\"XPA_IOCALLSXPA\"The key may be a symbol or a string, the value of a parameter may be a boolean, an integer or a string.  To set an XPA parameter, call the method:XPA.setconfig!(key, val) -> oldwhich returns the previous value of the parameter."
},

{
    "location": "library/#",
    "page": "Reference",
    "title": "Reference",
    "category": "page",
    "text": ""
},

{
    "location": "library/#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": "The following provides detailled documentation about types and methods provided by the XPA package.  This information is also available from the REPL by typing ? followed by the name of a method or a type."
},

{
    "location": "library/#XPA.Client",
    "page": "Reference",
    "title": "XPA.Client",
    "category": "type",
    "text": "An instance of the mutable structure XPA.Client represents a client connection in the XPA Messaging System.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.get",
    "page": "Reference",
    "title": "XPA.get",
    "category": "function",
    "text": "XPA.get([T, [dims,]] [xpa,] apt, params...)\n\nretrieves data from one or more XPA access points identified by apt (a template name, a host:port string or the name of a Unix socket file) with parameters params (automatically converted into a single string where the parameters are separated by a single space).  Optional argument xpa specifies an XPA handle (created by XPA.Client) for faster connections.  The returned value depends on the optional arguments T and dims.\n\nIf neither T nor dims are specified, an instance of XPA.Reply is returned with all the answer(s) from the XPA server(s).  The following keywords are available:\n\nKeyword nmax specifies the maximum number of answers, nmax=1 by default. Specify nmax=-1 to use the maximum number of XPA hosts.\nKeyword check specifies whether to check for errors.  If this keyword is set true, an error is thrown for the first error message encountered in the list of answers.  By default, check is false.\nKeyword mode specifies options in the form \"key1=value1,key2=value2\".\n\nIf T and, possibly, dims are specified, a single answer and no errors are expected (as if nmax=1 and check=true) and the data part of the answer is converted according to T which must be a type and dims which is an optional list of dimensions:\n\nIf only T is specified, it can be String to return a string interpreting the data as ASCII characters or a type like Vector{S} to return the largest vector of elements of type S that can be extracted from the returned data.\nIf both T and dims are specified, T can be a type like Array{S} or Array{S,N} and dims a list of N dimensions to retrieve the data as an array of type Array{S,N}.\n\nSee also: XPA.Client, XPA.get_data, XPA.set.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.Reply",
    "page": "Reference",
    "title": "XPA.Reply",
    "category": "type",
    "text": "XPA.Reply is used to store the answer(s) of XPA.get and XPA.set requests.  Method length applied to an object of type Reply yields the number of replies.  Methods XPA.get_data, XPA.get_server and XPA.get_message can be used to retrieve the contents of an object of type XPA.Reply.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.get_data",
    "page": "Reference",
    "title": "XPA.get_data",
    "category": "function",
    "text": "get_data([T, [dims,]] rep, i=1; preserve=false)\n\nyields the data associated with the i-th reply in XPA answer rep.  The returned value depends on the optional leading arguments T and dims:\n\nIf neither T nor dims are specified, a vector of bytes (UInt8) is returned.\nIf only T is specified, it can be String to return a string interpreting the data as ASCII characters or a type like Vector{S} to return the largest vector of elements of type S that can be extracted from the data.\nIf both T and dims are specified, T can be an array type like Array{S} or Array{S,N} and dims a list of N dimensions to retrieve the data as an array of type Array{S,N}.\n\nKeyword preserve can be used to specifiy whether or not to preserve the internal data buffer in rep for another call to XPA.get_data.  By default, preserve=true when T = String is specified and preserve=false otherwise.\n\nIn any cases, the type of the result is predictible, so there should be no type instability issue.\n\nSee also XPA.get, XPA.get_message, XPA.get_server.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.get_server",
    "page": "Reference",
    "title": "XPA.get_server",
    "category": "function",
    "text": "get_server(rep, i=1)\n\nyields the XPA identifier of the server which sent the i-th reply in XPA answer rep.  An empty string is returned if there is no i-th reply.\n\nSee also XPA.get, XPA.get_message.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.get_message",
    "page": "Reference",
    "title": "XPA.get_message",
    "category": "function",
    "text": "get_message(rep, i=1)\n\nyields the message associated with the i-th reply in XPA answer rep.  An empty string is returned if there is no i-th reply.\n\nSee also XPA.get, XPA.has_message, XPA.has_error, XPA.get_server.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.has_error",
    "page": "Reference",
    "title": "XPA.has_error",
    "category": "function",
    "text": "XPA.has_error(rep, i=1) -> boolean\n\nyields whether i-th XPA answer rep contains an error message.  The error message can be retrieved by calling XPA.get_message(rep, i).\n\nSee also XPA.get, XPA.has_message, XPA.get_message.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.has_errors",
    "page": "Reference",
    "title": "XPA.has_errors",
    "category": "function",
    "text": "XPA.has_errors(rep) -> boolean\n\nyields whether answer rep contains any error messages.\n\nSee also XPA.get, XPA.has_error, XPA.get_message.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.has_message",
    "page": "Reference",
    "title": "XPA.has_message",
    "category": "function",
    "text": "XPA.has_message(rep, i=1) -> boolean\n\nyields whether i-th XPA answer rep contains an error message.\n\nSee also XPA.get, XPA.has_message.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.set",
    "page": "Reference",
    "title": "XPA.set",
    "category": "function",
    "text": "XPA.set([xpa,] apt, params...; data=nothing) -> rep\n\nsends data to one or more XPA access points identified by apt with parameters params (automatically converted into a single string where the parameters are separated by a single space).  The result is an instance of XPA.Reply.  Optional argument xpa specifies an XPA handle (created by XPA.Client) for faster connections.\n\nThe following keywords are available:\n\ndata specifies the data to send, may be nothing, an array or a string. If it is an array, it must have contiguous elements (as a for a dense array) and must implement the pointer method.\nnmax specifies the maximum number of recipients, nmax=1 by default. Specify nmax=-1 to use the maximum possible number of XPA hosts.\nmode specifies options in the form \"key1=value1,key2=value2\".\ncheck specifies whether to check for errors.  If this keyword is set true, an error is thrown for the first error message encountered in the list of answers.  By default, check is false.\n\nSee also: XPA.Client, XPA.get.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.buffer",
    "page": "Reference",
    "title": "XPA.buffer",
    "category": "function",
    "text": "buf = buffer(data)\n\nyields an object buf representing the contents of data and which can be used as an argument to ccall without the risk of having the data garbage collected.  Argument data can be nothing, a dense array or a string.  If data is an array buf is just an alias for data.  If data is a string, buf is a temporary byte buffer where the string has been copied.\n\nStandard methods pointer and sizeof can be applied to buf to retieve the address and the size (in bytes) of the data and convert(Ptr{Cvoid},buf) can also be used.\n\nSee also XPA.set.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA-client-methods-and-types-1",
    "page": "Reference",
    "title": "XPA client methods and types",
    "category": "section",
    "text": "XPA.ClientXPA.getXPA.ReplyXPA.get_dataXPA.get_serverXPA.get_messageXPA.has_errorXPA.has_errorsXPA.has_messageXPA.setXPA.buffer"
},

{
    "location": "library/#XPA.Server",
    "page": "Reference",
    "title": "XPA.Server",
    "category": "type",
    "text": "An instance of the mutable structure XPA.Server represents a server connection in the XPA Messaging System.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.SendCallback",
    "page": "Reference",
    "title": "XPA.SendCallback",
    "category": "type",
    "text": "An instance of the XPA.SendCallback structure represents a callback called to serve an XPA.get request.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.ReceiveCallback",
    "page": "Reference",
    "title": "XPA.ReceiveCallback",
    "category": "type",
    "text": "An instance of the XPA.ReceiveCallback structure represents a callback called to serve an XPA.set request.\n\n\n\n\n\n"
},

{
    "location": "library/#Base.error-Tuple{XPA.Server,AbstractString}",
    "page": "Reference",
    "title": "Base.error",
    "category": "method",
    "text": "error(srv, msg) -> XPA.FAILURE\n\ncommunicates error message msg to the client when serving a request by XPA server srv.  This method shall only be used by the send/receive callbacks of an XPA server.\n\nAlso see: XPA.Server, XPA.message,           XPA.SendCallback, XPA.ReceiveCallback.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.setbuffer!",
    "page": "Reference",
    "title": "XPA.setbuffer!",
    "category": "function",
    "text": "XPA.setbuffer!(buf, data)\n\nor\n\nXPA.setbuffer!(buf, ptr, len)\n\nstore at the addresses given by the send buffer buf the address and size of a dynamically allocated buffer storing the contents of data (or a copy of the len bytes at address ptr).  This method is meant to be used in the send callback to store the result of an XPA.get request processed by an XPA server\n\nWe are always assuming that the answer to a XPA.get request is a dynamically allocated buffer which is deleted by XPAHandler.\n\nSee also XPA.Server, XPA.SendCallback and XPA.get.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.poll",
    "page": "Reference",
    "title": "XPA.poll",
    "category": "function",
    "text": "XPA.poll(sec, maxreq)\n\npolls for XPA events.  This method is meant to implement a polling event loop which checks for and processes XPA requests without blocking.\n\nArgument sec specifies a timeout in seconds (rounded to millisecond precision).  If sec is positive, the method blocks no longer than this amount of time.  If sec is strictly negative, the routine blocks until the occurence of an event to be processed.\n\nArgument maxreq specifies how many requests will be processed.  If maxreq < 0, then no events are processed, but instead, the returned value indicates the number of events that are pending.  If maxreq == 0, then all currently pending requests will be processed.  Otherwise, up to maxreq requests will be processed.  The most usual values for maxreq are 0 to process all requests and 1 to process one request.\n\nThe following example implements a polling loop which has no noticeable impact on the consumption of CPU when no requests are emitted to the server:\n\nconst __running = Ref{Bool}(false)\n\nfunction run()\n    global __running\n    __running[] = true\n    while __running[]\n        XPA.poll(-1, 1)\n    end\nend\n\nHere the global variable __running is a reference to a boolean whose value indicates whether to continue to run the XPA server(s) created by the process. The idea is to pass the reference to the callbacks of the server (as their client data for instance) and let the callbacks stop the loop by setting the contents of the reference to false.\n\nAnother possibility is to use XPA.mainloop (which to see).\n\nTo let Julia performs other tasks, the polling method may be repeatedly called by a Julia timer.  The following example does this.  Calling resume starts polling for XPA events immediately and then every 100ms.  Calling suspend suspends the processing of XPA events.\n\nconst __timer = Ref{Timer}()\n\nispolling() = (isdefined(__timer, 1) && isopen(__timer[]))\n\nresume() =\n    if ! ispolling()\n        __timer[] = Timer((tm) -> XPA.poll(0, 0), 0.0, interval=0.1)\n    end\n\nsuspend() =\n    ispolling() && close(__timer[])\n\nAlso see: XPA.Server, XPA.mainloop.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.message",
    "page": "Reference",
    "title": "XPA.message",
    "category": "function",
    "text": "XPA.message(srv, msg)\n\nsets a specific acknowledgment message back to the client. Argument srv is the XPA server serving the client and msg is the acknowledgment message. This method shall only be used by the receive callback of an XPA server.\n\nAlso see: XPA.Server, XPA.error,           XPA.ReceiveCallback.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.mainloop",
    "page": "Reference",
    "title": "XPA.mainloop",
    "category": "function",
    "text": "XPA.mainloop()\n\nruns XPA event loop which handles the requests sent to the server(s) created by this process.  The loop runs until all servers created by this process have been closed.\n\nIn the following example, the receive callback function close the server when it receives a \"quit\" command:\n\nfunction rproc(::Nothing, srv::XPA.Server, params::String,\n               buf::Ptr{UInt8}, len::Integer)\n    status = XPA.SUCCESS\n    if params == \"quit\"\n        close(srv)\n    elseif params == ...\n        ...\n    end\n    return status\nend\n\nAlso see: XPA.Server, XPA.mainloop.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA-server-methods-and-types-1",
    "page": "Reference",
    "title": "XPA server methods and types",
    "category": "section",
    "text": "XPA.ServerXPA.SendCallbackXPA.ReceiveCallbackerror(::XPA.Server,::AbstractString)XPA.setbuffer!XPA.pollXPA.messageXPA.mainloop"
},

{
    "location": "library/#XPA.list",
    "page": "Reference",
    "title": "XPA.list",
    "category": "function",
    "text": "XPA.list(xpa=XPA.TEMPORARY)\n\nyields a list of available XPA access points.  Optional argument xpa is a persistent XPA client connection; if omitted, a temporary client connection will be created.  The result is a vector of XPA.AccessPoint instances.\n\nAlso see: XPA.Client.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.AccessPoint",
    "page": "Reference",
    "title": "XPA.AccessPoint",
    "category": "type",
    "text": "An instance of the XPA.AccessPoint structure represents an available XPA server.  A vector of such instances is returned by the XPA.list utility.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.getconfig",
    "page": "Reference",
    "title": "XPA.getconfig",
    "category": "function",
    "text": "XPA.getconfig(key) -> val\n\nyields the value associated with configuration parameter key (a string or a symbol).  The following parameters are available (see XPA doc. for more information):\n\nKey Name Default Value\n\"XPA_MAXHOSTS\" 100\n\"XPA_SHORT_TIMEOUT\" 15\n\"XPA_LONG_TIMEOUT\" 180\n\"XPA_CONNECT_TIMEOUT\" 10\n\"XPA_TMPDIR\" \"/tmp/.xpa\"\n\"XPA_VERBOSITY\" true\n\"XPA_IOCALLSXPA\" false\n\nAlso see XPA.setconfig!.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.setconfig!",
    "page": "Reference",
    "title": "XPA.setconfig!",
    "category": "function",
    "text": "XPA.setconfig!(key, val) -> oldval\n\nset the value associated with configuration parameter key to be val.  The previous value is returned.\n\nAlso see XPA.getconfig.\n\n\n\n\n\n"
},

{
    "location": "library/#Utilities-1",
    "page": "Reference",
    "title": "Utilities",
    "category": "section",
    "text": "XPA.listXPA.AccessPointXPA.getconfigXPA.setconfig!"
},

{
    "location": "library/#XPA.SUCCESS",
    "page": "Reference",
    "title": "XPA.SUCCESS",
    "category": "constant",
    "text": "XPA.SUCCESS and XPA.FAILURE are the possible values returned by the callbacks of an XPA server.\n\n\n\n\n\n"
},

{
    "location": "library/#XPA.FAILURE",
    "page": "Reference",
    "title": "XPA.FAILURE",
    "category": "constant",
    "text": "XPA.SUCCESS and XPA.FAILURE are the possible values returned by the callbacks of an XPA server.\n\n\n\n\n\n\n\n"
},

{
    "location": "library/#Constants-1",
    "page": "Reference",
    "title": "Constants",
    "category": "section",
    "text": "XPA.SUCCESS\nXPA.FAILURE"
},

]}
