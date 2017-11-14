#include <stdio.h>
#include <xpa.h>

#define offset(type,field) (int)((char*)&((type*)0)->field - (char*)0)

int main(int argc, char* argv[])
{
  FILE* output = stdout;

  fprintf(output, "\n");
  fprintf(output, "_get_comm(xpa::Handle) =");
  fprintf(output, " _get_field(Ptr{Void}, xpa.ptr, %d, C_NULL)\n\n",
          offset(XPARec, comm));

#define GET1(param, type, field, def)                   \
  fprintf(output,                                       \
          "get_%s(xpa::Handle) ="                       \
          " _get_field(%s, xpa.ptr, %d, %s)\n\n",       \
          #param, #type, offset(XPARec, field), def)

#define GET2(param, type, field, def)                           \
  fprintf(output,                                               \
          "get_%s(xpa::Handle) ="                               \
          " _get_field(%s, _get_comm(xpa), %d, %s)\n\n",        \
          #param, #type, offset(XPACommRec, field), def)

  GET1(send_mode,    Cint,   send_mode,    "Cint(0)");
  GET1(recv_mode,    Cint,   receive_mode, "Cint(0)");
  GET1(name,         String, name,         "\"\"");
  GET1(class,        String, xclass,       "\"\"");
  GET1(method,       String, method,       "\"\"");
  GET1(sendian,      String, sendian,      "\"?\"");
  GET2(cmdfd,        Cint,   cmdfd,        "Cint(-1)");
  GET2(datafd,       Cint,   datafd,       "Cint(-1)");
  GET2(ack,          Cint,   ack,          "Cint(1)");
  GET2(status,       Cint,   status,       "Cint(0)");
  GET2(cendian,      String, cendian,      "\"?\"");

#undef GET1
#undef GET2

  return 0;
}
