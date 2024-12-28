#!/bin/sh

# Unset all aliases
'unalias' -a

# Ensure 'command' is not a user function
unset -f command

# Use shell dependent 'local' definition
local="$(command -v local)"
test -n "${local}" || local="$(command -v typeset)"
alias local="${local}"

# Program name
PROG="$(basename -- "$0")"

####

# Print usage information
usage ()
{
    cat << EOF
Usage: ${PROG} [options] infile
EOF
}

# Print help information
usage_help ()
{
    usage
    cat << EOF

    -D var	define 'var'
    -U var	undefine 'var'
    -I dir	add 'dir' to the search list
    -o outfile	output file name

    infile	input file name
EOF
    exit 0
}

####

# Parse command line options
get_options ()
{
    local opt=""

    case "$1" in ( '-?' | '-help' | '--help' ) usage_help ;; esac
    while getopts ":D:I:U:o:" opt ; do
	case "${opt}" in
	    ( 'D' ) def_var "${OPTARG}"     || return 1 ;;
	    ( 'I' ) add_inclist "${OPTARG}" || return 1 ;;
	    ( 'U' ) undef_var "${OPTARG}"   || return 1 ;;
	    ( 'o' ) OUTFILE="${OPTARG}" ;;
	    ( ':' ) err "missing argument for option -- '${OPTARG}'" ; usage ; return 1 ;;
	    ( '?' ) err "unknown option -- '${OPTARG}'" ; usage ; return 1 ;;
	    (  *  ) err "no handler for option '${opt}'" ; return 1 ;;
	esac
    done
    shift $(( OPTIND - 1 ))
    test $# -le 1 || { err "too many arguments" ; usage ; return 1 ; }
    INFILE="${1:-}"
}

####

# Print error message
err ()
{
    printf "%s: error: %s\n" "${PROG}" "$*" >&2
}

# Execute command
cmd ()
{
    command ${1+"$@"} 2>/dev/null
}

####

# Check file
check_file ()
{
    local f="$1"

    test -n "${f}" || return 1
    test -f "${f}" || { err "file '${f}' not found"  ; return 1 ; }
    test -r "${f}" || { err "can't open file '${f}'" ; return 1 ; }
}

# Quote single quotes
squote ()
{
    local e="$1"
    local h=""
    local n=""

    while : ; do
	# Check for quotes
	case "${e}" in
	    ( '' ) break ;;		# Empty string
	    ( *"'"* )
		# There are quotes in the element
		h="${e%%"'"*}"		# Get 'head' till quote
		e="${e#${h}"'"}"	# Cut 'head' with quote
		n="${n}${h}'\''"	# Add 'head' to 'new' with quoted quote
		;;
	    ( * )
		# No more quotes found
		e="${n}${e}"		# Construct final string
		break			# and exit the cycle
		;;
	esac
    done
    printf "'%s'" "${e}"
}

# Trim leading spaces
ltrim ()
{
    local s="$*"
    local d=""

    case "${s}" in ( [[:space:]]* ) d="${s%%[![:space:]]*}" ;; esac
    printf "%s" "${s#${d}}"
}

# Trim trailing spaces
rtrim ()
{
    local s="$*"
    local d=""

    case "${s}" in ( *[[:space:]] ) d="${s##*[![:space:]]}" ;; esac
    printf "%s" "${s%${d}}"
}

# Trim spaces
trim ()
{
    printf "%s" "$(ltrim "$(rtrim "$*")")"
}

####

# 'readlink' replacement
_readlink ()
{
    local p="$1"
    local l=""

    # Get link path from 'ls' output
    l="$(cmd ls -l "${p}")" || return 1
    printf "%s" "${l##*" -> "}"
}

# 'realpath' replacement
_realpath ()
{
    local p="$1"
    local b=""
    local d=""
    local l=""
    local readlink=""

    # If path does not exist then return error
    test -n "${p}" && test -e "${p}" || return 1
    if test -d "${p}" ; then
	# If path is directory just go there and get 'pwd'
	p="$(cd -P -- "${p}" ; pwd)"
    else
	# Determine 'readlink'
	readlink="$(command -v readlink)"
	test -n "${readlink}" || readlink="_readlink"
	# Split path to 'basename' and 'dirname'
	case "${p}" in
	    ( */* ) b="${p##*/}" ; d="${p%/*}" ;;
	    (  *  ) b="${p}" ; d="${PWD}" ;;
	esac
	while test -L "${d}/${b}" ; do
	    l="$("${readlink}" "${d}/${b}")" || return 1
	    case "${l}" in
		( */* )
		    b="${l##*/}"	# Get next 'basename'
		    case "${l}" in
			( /* ) d="${l%/*}" ;;		# 'Absolute' path
			(  * ) d="${d}/${l%/*}" ;;	# 'Relative' path
		    esac
		    ;;
		(  *  ) b="${l}" ;;	# Link points to file in the same directory
	    esac
	done
	d="$(cd -P -- "${d:-/}" ; pwd)"
	p="${d%/}/${b}"	# Final physical path
    fi
    printf "%s" "${p}"
}

# Canonicalize path name
canon_path ()
{
    local p="$1"
    local realpath="$(command -v realpath)"

    test -n "${realpath}" || realpath="_realpath"
    p="$("${realpath}" "${p}")" || return 1
    printf "%s" "${p}"
}

####

# Check variable name (in subshell)
check_vname ()
(
    LC_ALL=C		# Check variable name in POSIX locale
    case "$1" in
	( '' | '_' | [![:alpha:]_]* | [[:alpha:]_]*[![:alnum:]_]* )
	    err "illegal variable name: '$1'"
	    return 1 ;;
    esac
)

# Define variable
def_var ()
{
    local var="$1"
    local val="1"	# Default value

    case "${var}" in ( *'='* ) val="${var#*=}" ; var="${var%%=*}" ;; esac
    check_vname "${var}" && eval "V_${var}=\"\${val}\"" || return 1
}

# Undefine variable
undef_var ()
{
    check_vname "$1" && unset -v "V_$1" || return 1
}

# Add directory to include list
add_inclist ()
{
    INCLIST="${INCLIST:+"${INCLIST} "}$(squote "$1")"
}

####

# Search include file
search_inc ()
{
    local f="$1"
    local d=""

    case "${f}" in
	( /* ) test -e "${f}" && return 0 ;;	# Absolute path
	(  * )
	    # Relative to CURFILE
	    case "${CURFILE}" in
		( */* ) d="${CURFILE%/*}" ;;
		(  *  ) d="${PWD}" ;;
	    esac
	    # Prepend search list with CURFILE path
	    eval "set -- $(squote "${d}") ${INCLIST}"
	    for d in "$@" ; do
		test -e "${d}/${f}" && return 0
	    done
	    ;;
    esac
    return 1
}

####

# Process '#%include' directive
do_include ()
{
    local f="$1"

    case "$f" in ( \"*\" ) f="${f#\"}" ; f="${f%\"}" ;; esac	# Remove quotes
    test -n "${f}" || { err "no parameters set for '#%include' directive" ; return 1 ; }
    search_inc "${f}" || { err "can't find include file '${f}'" ; return 1 ; }
    process_file "${f}"
}

# Examine directive and call handler
do_directive ()
{
    local s="$(trim "${CURLINE#'#%'}")"		# Cut '#%' and trim spaces
    local d="${s%%[[:space:]]*}"		# Get directive
    local args="$(ltrim "${s#${d}}")"		# Get arguments

    case "${d}" in
	( '' ) ;;	# Skip empty directives
	( "include" ) do_include "${args}" || return 1 ;;
	( *  ) err "unknown directive '${d}'" ; return 1 ;;
    esac
}

# Output current line
output_line ()
{
    printf "%s\n" "${CURLINE}" >&3
}

# Process line
process_line ()
{
    case "${CURLINE}" in
	( '#%'* ) do_directive || return 1 ;;
	( * ) output_line ;;
    esac
}

# Process file (in subshell)
process_file ()
(
    local if="$1"
    local cf=""
    local ln=0

    # Check file and open for input
    # FSTACK (file stack) is used for cycles determination
    if test -n "${if}" ; then
	check_file "${if}"		&&
	cf="$(canon_path "${if}")"	&&
	case "|${FSTACK}|" in
	    ( *"|${cf}|"* ) err "cyclic include of file '${cf}'" ; false ;;
	    ( * ) FSTACK="${FSTACK:+${FSTACK}|}${cf}" ;;
	esac				&&
	exec 0< "${if}"			||	# Open input file
	return 1
    fi

    # Read file
    # CURFILE (current file) is used by 'search_inc'
    # CURLINE (current line) is used as global buffer
    CURFILE="${if}"
    while IFS= read -r CURLINE ; do
	ln=$(( ln + 1 ))
	process_line || { err "in file '${if:-stdin}':${ln}" ; return 1 ; }
    done
)

####

# Initialization subroutine
init ()
{
    set -o noglob	# Do not expand pathnames
    INCLIST=""		# List of include directories
    INFILE=""		# Input file (empty for 'stdin')
    OUTFILE=""		# Output file (empty for 'stdout')
}

# Startup subroutine
startup ()
{
    # Check input file
    case "${INFILE}" in ( '-' ) INFILE="" ;; esac

    # Check output file
    case "${OUTFILE}" in ( '-' ) OUTFILE="" ;; esac
    if test -n "${OUTFILE}" ; then
	# If output file is set then try to create it
	( : > "${OUTFILE}" ) 2>/dev/null ||
	    { err "can't create output file '${OUTFILE}'" ; return 1 ; }
	exec 3> "${OUTFILE}"	# Open output file as file descriptor '3'
    else
	exec 3>&1		# Copy 'stdout' to file descriptor '3'
    fi
}

# Clean up subroutine
cleanup ()
{
    exec 3>&-	# Close used file descriptors
}

# Clean up the staff and exit with error
clean_fail ()
{
    cleanup
    test -n "${OUTFILE}" && cmd rm -f "${OUTFILE}"
    fail "${1:-1}"
}

# Exit with error code
fail ()
{
    exit "${1:-1}"
}

####

# Main subroutine
main ()
{
    init && get_options "$@" && startup || fail
    trap 'clean_fail 130' HUP INT TERM
    process_file "${INFILE}" || clean_fail
    cleanup
}

# Call main subroutine
main "$@"
