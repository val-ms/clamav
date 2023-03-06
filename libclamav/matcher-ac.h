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

#ifndef __MATCHER_AC_H
#define __MATCHER_AC_H

#include <sys/types.h>

#include "filetypes.h"
#include "clamav-types.h"
#include "fmap.h"
#include "hashtab.h"
#include "matcher-ac-structures.h"
#include "matcher.h"

/**
 * @brief Add a simple sub-pattern into the AC trie.
 *
 * Simple sub-patterns may not include any wildcards or [a-b] anchored byte ranges.
 */
cl_error_t cli_ac_addpatt(struct cli_matcher *root, struct cli_ac_patt *pattern);

/**
 * @brief Increment the count for a subsignature of a logical signature.
 *
 * This is and alternative to lsig_increment_subsig_match() for use in subsigs that don't have a specific offset,
 * like byte-compare subsigs and fuzzy-hash subsigs.
 */
void lsig_increment_subsig_match(struct cli_ac_data *mdata, uint32_t lsig_id, uint32_t subsig_id);

cl_error_t cli_ac_initdata(struct cli_ac_data *data, uint32_t partsigs, uint32_t lsigs, uint32_t reloffsigs, uint8_t tracklen);

/**
 * @brief Increment the count for a subsignature of a logical signature.
 *
 * Increment a logical signature subsignature match count.
 *
 * @param root      The root storing all pattern matching data. I.e. "the database in memory."
 * @param mdata     Match result data
 * @param lsig_id   The current logical signature id
 * @param subsig_id The current subsignature id
 * @param realoff   Offset where the match occured
 * @param partial   0 if whole pattern, or >0 for a partial-patterns. That is one split with wildcards like * or {n-m}.
 * @return cl_error_t
 */
cl_error_t lsig_sub_matched(const struct cli_matcher *root, struct cli_ac_data *mdata, uint32_t lsig_id, uint32_t subsig_id, uint32_t realoff, int partial);

cl_error_t cli_ac_chkmacro(struct cli_matcher *root, struct cli_ac_data *data, unsigned lsigid1);
int cli_ac_chklsig(const char *expr, const char *end, uint32_t *lsigcnt, unsigned int *cnt, uint64_t *ids, unsigned int parse_only);
void cli_ac_freedata(struct cli_ac_data *data);
cl_error_t cli_ac_scanbuff(const unsigned char *buffer, uint32_t length, const char **virname, void **customdata, struct cli_ac_result **res, const struct cli_matcher *root, struct cli_ac_data *mdata, uint32_t offset, cli_file_t ftype, struct cli_matched_type **ftoffset, unsigned int mode, cli_ctx *ctx);
cl_error_t cli_ac_buildtrie(struct cli_matcher *root);
cl_error_t cli_ac_init(struct cli_matcher *root, uint8_t mindepth, uint8_t maxdepth, uint8_t dconf_prefiltering);
cl_error_t cli_ac_caloff(const struct cli_matcher *root, struct cli_ac_data *data, const struct cli_target_info *info);
void cli_ac_free(struct cli_matcher *root);

/**
 * @brief Add a complex sub-pattern into the AC trie.
 *
 * Complex sub-patterns are the body content between `{n-m}` and `{*}` wildcards in content match signatures.
 * And `{n}` wildcards should have already been replaced with `??` characters and are included in the patterns.
 */
cl_error_t cli_ac_addsig(struct cli_matcher *root, const char *virname, const char *hexsig, uint8_t sigopts, uint32_t sigid, uint16_t parts, uint16_t partno, uint16_t rtype, uint16_t type, uint32_t mindist, uint32_t maxdist, const char *offset, const uint32_t *lsigid, unsigned int options);

#endif
