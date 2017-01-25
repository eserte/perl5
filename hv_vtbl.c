/*    hv_vtbl.c
 *
 *    Copyright (C) 2017 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

/* TODO: Insert LotR quote here. */

#include "EXTERN.h"
#define PERL_IN_HV_VTBL_C
#define PERL_HASH_INTERNAL_ACCESS
#include "perl.h"

STATIC void
S_hv_mock_std_vtable_init(pTHX_ HV *hv)
{
    PERL_UNUSED_CONTEXT;
    PERL_UNUSED_ARG(hv);
}

STATIC void
S_hv_mock_std_vtable_destroy(pTHX_ HV *hv)
{
    PERL_UNUSED_CONTEXT;
    PERL_UNUSED_ARG(hv);
}

STATIC SV *
S_hv_mock_std_vtable_delete(pTHX_ HV *hv, SV *keysv, const char *key,
                            STRLEN klen, int key_flags, I32 delete_flags,
                            U32 hash)
{
    return hv_delete_common(hv, keysv, key, klen,
		            key_flags, delete_flags, hash);
}

HV_VTBL PL_mock_std_vtable = {
        S_hv_mock_std_vtable_init,
        S_hv_mock_std_vtable_destroy,
        /* S_hv_mock_std_vtable_fetch, */
	S_hv_mock_std_vtable_delete
};

/*
 * ex: set ts=8 sts=4 sw=4 et:
 */
