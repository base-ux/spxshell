#!/bin/sh

# Set variables
D="$(dirname -- "$0")"
D="$(cd -- "${D}" ; pwd)"

SRCDIR="${D}"
OUTDIR="${D}/out"

SPXGEN_SHT="${SRCDIR}/spxgen.sht"
SPXGEN="${OUTDIR}/spxgen.sh"
SPXGEN_BS="${OUTDIR}/spxgen-bs.sh"

SPXBSSRCS="
sys/prolog
sys/msg.shi
sys/pathabs.shi
sys/pathcanon.shi
sys/checkfile.shi
spxgen.sht
"

# Check files
for _src in ${SPXBSSRCS} ; do
    _f="${SRCDIR}/${_src}"
    BSFILES="${BSFILES:+"${BSFILES} "}${_f}"
    test -f "${_f}" && continue
    printf "%s: file '%s' not found\n" "$0" "${_f}"
    exit 1
done

# Check out directory
test -d "${OUTDIR}" || mkdir -p "${OUTDIR}"

# Assemble bootstrap version of 'spxgen.sh'
eval cat "${BSFILES}" |
    sed -e "/^#%prolog/r ${SRCDIR}/sys/prolog" -e "/^#%prolog/d" > "${SPXGEN_BS}"

# Generate 'spxgen.sh' with bootstrap version
command -p sh "${SPXGEN_BS}" "${SPXGEN_SHT}" > "${SPXGEN}"
