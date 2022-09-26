/*
 *  Copyright (C) 2022 Cisco Systems, Inc. and/or its affiliates. All rights reserved.
 *
 *  Authors: Micah Snyder
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

#ifndef __MATCHER_OFFSET_H
#define __MATCHER_OFFSET_H

#include "clamav.h"

/*
 * These are a magic numbers used for a variety of signature size fields.
 * The values are selected to be large, uncommon, and must fit within a size_t.
 */
#define CLI_SIZE_ANY 0xffffffff
#define CLI_SIZE_NONE 0xfffffffe

enum pattern_off_type {
    PATTERN_OFF_ABSOLUTE  = 1,
    PATTERN_OFF_EOF_MINUS = 2,
    PATTERN_OFF_EP_PLUS   = 3,
    PATTERN_OFF_EP_MINUS  = 4,
    PATTERN_OFF_SL_PLUS   = 5,
    PATTERN_OFF_SX_PLUS   = 6,
    PATTERN_OFF_VERSION   = 7,
    PATTERN_OFF_MACRO     = 8,
    PATTERN_OFF_SE        = 9,
    PATTERN_OFF_NONE      = 0xfe
};

typedef struct pattern_offset_data {
    /* Offset from start of offset_min. */
    uint32_t offset_value;

    /* Amount the match may shift from the start of the offset. Uncommonly specified. */
    uint32_t max_shift;

    /* lower boundary for matching within a specific section. */
    uint32_t offset_min;
    /* upper boundary for matching within a specific section. */
    uint32_t offset_max;

    /* section offsets are unknown until scanning a specific file, so the offsets are recalculated using the requested section at that time. */
    uint16_t section_number;

    /* pattern_off_type enum stored as uint8_t to conserve memory */
    uint8_t type;
} pattern_offset_data;

#endif
