/*
 *  Copyright (C) 2013-2022 Cisco Systems, Inc. and/or its affiliates. All rights reserved.
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

#ifndef __MATCHER_AC_STRUCTURES_H
#define __MATCHER_AC_STRUCTURES_H

#include "clamav.h"

#define AC_CH_MAXDIST 32
#define ACPATT_ALTN_MAXNEST 15

/* AC scanning modes */
#define AC_SCAN_VIR 1
#define AC_SCAN_FT 2

/* Pattern options */
#define ACPATT_OPTION_NOOPTS 0x00
#define ACPATT_OPTION_NOCASE 0x01
#define ACPATT_OPTION_FULLWORD 0x02
#define ACPATT_OPTION_WIDE 0x04
#define ACPATT_OPTION_ASCII 0x08

#define ACPATT_OPTION_ONCE 0x80

struct cli_subsig_matches {
    uint32_t last;
    uint32_t next;
    uint32_t offsets[16]; /* offsets[] is variable length */
};

struct cli_lsig_matches {
    uint32_t subsigs;
    struct cli_subsig_matches *matches[1]; /* matches[] is variable length */
};

typedef struct cli_ac_data {
    bool initialized;
    uint32_t ***offmatrix;
    uint32_t partsigs, lsigs, reloffsigs;
    uint32_t **lsigcnt;
    uint32_t **lsigsuboff_last, **lsigsuboff_first;
    struct cli_lsig_matches **lsig_matches;
    uint8_t *yr_matches;
    uint32_t *offset;
    uint32_t macro_lastmatch[32];
    /** Hashset for versioninfo matching */
    const struct cli_hashset *vinfo;
    uint32_t min_partno;
} cli_ac_data;

struct cli_alt_node {
    uint16_t *str;
    uint16_t len;
    uint8_t unique;
    struct cli_alt_node *next;
};

struct cli_ac_special {
    union {
        unsigned char *byte;
        unsigned char **f_str;
        struct cli_alt_node *v_str;
    } alt;
    uint16_t len[2], num; /* 0=MIN, 1=MAX */
    uint16_t type, negative;
};

struct cli_ac_patt {
    uint16_t *pattern, *prefix, length[3], prefix_length[3];
    uint32_t mindist, maxdist;
    uint32_t sigid;
    uint32_t lsigid[3];
    uint16_t ch[2];
    char *virname;
    void *customdata;
    uint16_t ch_mindist[2];
    uint16_t ch_maxdist[2];
    uint16_t parts, partno, special, special_pattern;
    struct cli_ac_special **special_table;
    uint16_t rtype, type;
    uint32_t offdata[4], offset_min, offset_max;
    uint32_t boundary;
    uint8_t depth;
    uint8_t sigopts;
};

struct cli_ac_list {
    struct cli_ac_patt *me;
    union {
        struct cli_ac_node *node;
        struct cli_ac_list *next;
    };
    struct cli_ac_list *next_same;
};

struct cli_ac_node {
    struct cli_ac_list *list;
    struct cli_ac_node **trans, *fail;
};

#define IS_LEAF(node) (!node->trans)
#define IS_FINAL(node) (!!node->list)

struct cli_ac_result {
    const char *virname;
    void *customdata;
    uint32_t offset;
    struct cli_ac_result *next;
};

#endif //__MATCHER_AC_STRUCTURES_H
