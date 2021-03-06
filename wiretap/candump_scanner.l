/* candump_scanner.l
 *
 * Wiretap Library
 * Copyright (c) 1998 by Gilbert Ramirez <gram@alumni.rice.edu>
 *
 * Support for candump log file format
 * Copyright (c) 2019 by Maksim Salau <maksim.salau@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

%option reentrant
%option noyywrap
%option noinput
%option nounput
%option batch
%option never-interactive
%option prefix="candump_"
%option extra-type="candump_state_t *"
%option yylineno
%option nodefault

%option noyy_scan_buffer
%option noyy_scan_bytes
%option noyy_scan_string

/*
 * We have to override the memory allocators so that we don't get
 * "unused argument" warnings from the yyscanner argument (which
 * we don't use, as we have a global memory allocator).
 *
 * We provide, as macros, our own versions of the routines generated by Flex,
 * which just call malloc()/realloc()/free() (as the Flex versions do),
 * discarding the extra argument.
 */
%option noyyalloc
%option noyyrealloc
%option noyyfree

%{

#include <ws_diag_control.h>
#include <wiretap/file_wrappers.h>
#include "candump_parser.h"
#include "candump_priv.h"

#ifndef HAVE_UNISTD_H
#define YY_NO_UNISTD_H
#endif

static int candump_yyinput(void *buf, unsigned int max_size,
                           candump_state_t *state)
{
    int result = file_read(buf, max_size, state->fh);

    if (result == EOF)
    {
        state->err = file_error(state->fh, &state->err_info);
        result     = YY_NULL;
    }

    return result;
}

#define YY_INPUT(buf, result, max_size) \
    do { (result) = candump_yyinput((buf), (max_size), yyextra); } while (0)

/*
 * Sleazy hack to suppress compiler warnings in yy_fatal_error().
 */
#define YY_EXIT_FAILURE ((void)yyscanner, 2)

/*
 * Macros for the allocators, to discard the extra argument.
 */
#define candump_alloc(size, yyscanner)          (void *)malloc(size)
#define candump_realloc(ptr, size, yyscanner)   (void *)realloc((char *)(ptr), (size))
#define candump_free(ptr, yyscanner)            free((char *)(ptr))

DIAG_OFF_FLEX

%}

INT [0-9]
HEX [0-9A-Fa-f]

%%

[ \t]                   { return TOKEN_SPACE; };
[\r\n]                  { return TOKEN_ENDL; }

\({INT}+\.{INT}+\)      {
                            yyextra->token.v0 = strtoul(yytext + 1, NULL, 10);
                            yyextra->token.v1 = strtoul(strchr(yytext, '.') + 1, NULL, 10);
                            return TOKEN_TIMESTAMP;
                        }

R{INT}                  {
                            yyextra->token.v0 = strtoul(yytext + 1, NULL, 10);
                            return TOKEN_RTR;
                        }

R                       {
                            yyextra->token.v0 = 0;
                            return TOKEN_RTR;
                        }

{HEX}{8}#               {
                            yyextra->token.v0 = strtoul(yytext, NULL, 16);
                            return TOKEN_EXT_ID;
                        }

{HEX}{3}#               {
                            yyextra->token.v0 = strtoul(yytext, NULL, 16);
                            return TOKEN_STD_ID;
                        }

{HEX}{HEX}              {
                            yyextra->token.v0 = strtoul(yytext, NULL, 16);
                            return TOKEN_BYTE;
                        }

#{HEX}                  {
                            yyextra->token.v0 = strtoul(yytext + 1, NULL, 16);
                            return TOKEN_FLAGS;
                        }

.                       { return TOKEN_UNKNOWN; }

%%

DIAG_ON_FLEX
