#!/bin/sh

# Set variables
PRODUCT="spxshell"
VERSION="0.14.5"

PROG="$(basename -- "$0")"

D="$(dirname -- "$0")"
D="$(cd -- "${D}" ; pwd)"

SRCDIR="${D}"
OUTDIR="${D}/out"

SPXGEN_SHT="${SRCDIR}/spxgen.sht"
INSTALL_SHT="${SRCDIR}/install.sht"

SPXGEN_BS="${OUTDIR}/spxgen-bs.sh"

SPXGEN="${OUTDIR}/spxgen.sh"
MKDEPLOY="${OUTDIR}/mkdeploy.sh"
INSTALL="${OUTDIR}/install.sh"

SPXBSSRCS="
sys/prolog
sys/checkfile
sys/chkvname
sys/cmd
sys/config
sys/msg
sys/pathabs
sys/pathcanon
sys/vars
spxgen.sht
"

SRCS="
cfbackup.sht
delcore.sht
mkdeploy.sht
mkhlist.sht
nmon-cleanup.sht
nmon-collect.sht
sysexec.sht
"

FILELIST=""

SH="$(command -pv sh)"

# Generate 'spxgen.sh'
bootstrap ()
{
    # Check files
    for _src in ${SPXBSSRCS} ; do
	_f="${SRCDIR}/${_src}"
	BSFILES="${BSFILES:+"${BSFILES} "}${_f}"
	test -f "${_f}" && continue
	printf "%s: file '%s' not found\n" "${PROG}" "${_f}"
	return 1
    done

    # Assemble bootstrap version of 'spxgen.sh'
    eval cat "${BSFILES}" > "${SPXGEN_BS}"

    # Generate 'spxgen.sh' with bootstrap version
    ${SH} "${SPXGEN_BS}" -o "${SPXGEN}" "${SPXGEN_SHT}" || return 1
}

# Generate all scripts with 'spxgen.sh'
build ()
{
    # Generate 'spxgen.sh' first
    bootstrap || return 1
    # Check files and generate scripts
    for _src in ${SRCS} ; do
	_f="${SRCDIR}/${_src}"
	if ! test -f "${_f}" ; then
	    printf "%s: file '%s' not found\n" "${PROG}" "${_f}"
	    return 1
	fi
	_outfile="${OUTDIR}/${_src%.sht}.sh"
	${SH} "${SPXGEN}" -o "${_outfile}" "${_f}" || return 1
	FILELIST="${FILELIST:+"${FILELIST} "}${_outfile}"
    done
    # Generate 'install.sh'
    ${SH} "${SPXGEN}" -o "${INSTALL}" "${INSTALL_SHT}" || return 1
}

# Create deploy script
deploy ()
{
    # Build scripts first
    build || return 1
    ${SH} "${MKDEPLOY}" \
	-s "${OUTDIR}" \
	-o "${OUTDIR}/${PRODUCT}-v${VERSION}.sh" \
	-P "${PRODUCT}" -V "${VERSION}" \
	-i "${INSTALL}" \
	-f "${SPXGEN}" \
	-f "${FILELIST}"  \
    || return 1
}

# Call install script
install ()
{
    # Build scripts first
    build || return 1
    ${SH} "${INSTALL}" || return 1
}

# Show usage information
usage ()
{
    cat << EOF
Usage: ${PROG} target
    'target' is one of the following ('all' if missed):
    all		build all
    bootstrap	build 'spxgen.sh'
    build	build other scripts
    deploy	create deploy script
    install	call install script
EOF
}

# Main subroutine
main ()
{
    # Check command line arguments
    test $# -le 1 || { usage ; return 1 ; }
    test $# -gt 0 && _target="$1" || _target="all"
    # Create output directory
    test -d "${OUTDIR}" || mkdir -p "${OUTDIR}" || return 1
    case "${_target}" in
	( "all" ) build ;;
	( "bootstrap" ) bootstrap ;;
	( "build" ) build ;;
	( "deploy" ) deploy ;;
	( "install" ) install ;;
	( * ) usage ; return 1 ;;
    esac
}

# Call main subroutine
main "$@"
