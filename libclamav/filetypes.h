/*
 *  Copyright (C) 2013-2023 Cisco Systems, Inc. and/or its affiliates. All rights reserved.
 *  Copyright (C) 2007-2013 Sourcefire, Inc.
 *
 *  Authors: Tomasz Kojm
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2 as
 *  published by the Free Software Foundation.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef __FILETYPES_H
#define __FILETYPES_H

#include <sys/types.h>

#include "clamav.h"
#include "fmap.h"
#include "filetypes_structures.h"
#include "others.h"

cli_file_t cli_ftcode(const char *name);
const char *cli_ftname(cli_file_t code);
void cli_ftfree(const struct cl_engine *engine);
cli_file_t cli_compare_ftm_file(const unsigned char *buf, size_t buflen, const struct cl_engine *engine);
cli_file_t cli_compare_ftm_partition(const unsigned char *buf, size_t buflen, const struct cl_engine *engine);
cli_file_t cli_determine_fmap_type(cli_ctx *ctx, cli_file_t basetype);

#endif
