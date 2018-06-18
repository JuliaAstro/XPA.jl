/*
 * gencode.c --
 *
 * Generate constants definitions for Julia.
 *
 *------------------------------------------------------------------------------
 *
 * This file is part of XPA.jl released under the MIT "expat" license.
 * Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/XPA.jl).
 */

#include <stdio.h>
#include <xpa.h>

/*
 * Determine the offset of a field in a structure.
 */
#define OFFSET(type, field) (int)((char*)&((type*)0)->field - (char*)0)

/*
 * Define a Julia constant with the offset (in bytes) of a field of a
 * C-structure.
 */
#define DEF_OFFSETOF(ident, type, field)                \
  fprintf(output, "const _offsetof_" ident " = %3ld\n", \
          (long)OFFSET(type, field))

int main(int argc, char* argv[])
{
  FILE* output = stdout;

  fprintf(output, "\n");
  fprintf(output, "# Field offsets in main XPARec structure.\n");
  DEF_OFFSETOF("class    ", XPARec, xclass);
  DEF_OFFSETOF("name     ", XPARec, name);
  DEF_OFFSETOF("send_mode", XPARec, send_mode);
  DEF_OFFSETOF("recv_mode", XPARec, receive_mode);
  DEF_OFFSETOF("method   ", XPARec, method);
  DEF_OFFSETOF("sendian  ", XPARec, sendian);
  DEF_OFFSETOF("comm     ", XPARec, comm);

  fprintf(output, "\n");
  fprintf(output, "# Field offsets in XPACommRec structure.\n");
  DEF_OFFSETOF("comm_status ", XPACommRec, status);
  DEF_OFFSETOF("comm_cmdfd  ", XPACommRec, cmdfd);
  DEF_OFFSETOF("comm_datafd ", XPACommRec, datafd);
  DEF_OFFSETOF("comm_cendian", XPACommRec, cendian);
  DEF_OFFSETOF("comm_ack    ", XPACommRec, ack);
  DEF_OFFSETOF("comm_buf    ", XPACommRec, buf);
  DEF_OFFSETOF("comm_len    ", XPACommRec, len);

  return 0;
}
