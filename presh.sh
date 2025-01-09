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
	    ( 'D' ) add_var "${OPTARG}" ;;
	    ( 'I' ) add_inclist "${OPTARG}" ;;
	    ( 'U' ) del_var "${OPTARG}" ;;
	    ( 'o' ) OUTFILE="${OPTARG}" ;;
	    ( ':' ) err "missing argument for option -- '${OPTARG}'" ; usage ; false ;;
	    ( '?' ) err "unknown option -- '${OPTARG}'" ; usage ; false ;;
	    (  *  ) err "no handler for option '${opt}'" ; false ;;
	esac || return 1
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
	    ( *\'* )
		# There are quotes in the element
		h="${e%%\'*}"		# Get 'head' till quote
		e="${e#*\'}"		# Cut 'head' with quote
		n="${n}${h}'\''"	# Add 'head' to 'new' with quoted quote
		;;
	    ( * )
		# No more quotes found
		e="'${n}${e}'"		# Construct final string
		break			# and exit the cycle
		;;
	esac
    done
    printf "%s" "${e}"
}

# Trim leading spaces
ltrim ()
{
    local s="$*"
    local d=""

    case "${s}" in ( [[:space:]]* ) d="${s%%[![:space:]]*}" ;; esac
    printf "%s" "${s#"${d}"}"
}

# Trim trailing spaces
rtrim ()
{
    local s="$*"
    local d=""

    case "${s}" in ( *[[:space:]] ) d="${s##*[![:space:]]}" ;; esac
    printf "%s" "${s%"${d}"}"
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

# Add directory to include list
add_inclist ()
{
    INCLIST="${INCLIST:+"${INCLIST} "}$(squote "$1")"
}

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

# Add variable
add_var ()
{
    local var="$1"
    local val="1"	# Default value

    case "${var}" in ( *'='* ) val="${var#*=}" ; var="${var%%=*}" ;; esac
    check_vname "${var}" && eval "$(def_var "${var}" "${val}")" || return 1
}

# Delete variable
del_var ()
{
    check_vname "$1" && eval "$(undef_var "$1")" || return 1
}

# Print command to define variable
def_var ()
{
    printf "V_%s=%s" "$1" "$(squote "$2")"
}

# Print command to undefine variable
undef_var ()
{
    printf "unset -v V_%s" "$1"
}

####

# Search include file
search_inc ()
{
    local f="$1"
    local d=""
    local n=""

    case "${f}" in
	( /* ) test -e "${f}" && n="${f}" ;;	# Absolute path
	(  * )
	    # Relative to CURFILE
	    case "${CURFILE}" in
		( */* ) d="${CURFILE%/*}" ;;
		(  *  ) d="${PWD}" ;;
	    esac
	    # Prepend search list with CURFILE path
	    eval "set -- $(squote "${d}") ${INCLIST}"
	    for d in "$@" ; do
		test -e "${d}/${f}" && { n="${d}/${f}" ; break ; }
	    done
	    ;;
    esac
    test -n "${n}" || { err "can't find include file '${f}'" ; return 1 ; }
    printf "%s" "${n}"
}

####

# Evaluate value and add to return string
eval_ret ()
{
    case "$1" in
	( '' ) ;;
	( *  )
	    eval "$1"
	    RET="${RET:+"${RET} ; "}$1"
	    ;;
    esac
}

# Process 'define' directive
do_define ()
{
    local args="$1"
    local var="${args%%[[:space:]]*}"		# Get variable name
    local val="$(ltrim "${args#"${var}"}")"	# Get variable value

    test -n "${var}" || { err "no parameters set for 'define' directive" ; return 1 ; }
    check_vname "${var}" || return 1
    test -n "${val}" || val="1"		# Default value
    case "${val}" in ( \"*\" ) val="${val#\"}" ; val="${val%\"}" ;; esac	# Remove quotes
    eval_ret "$(def_var "${var}" "${val}")"
}

# Process 'include' directive
do_include ()
{
    local f="$1"

    case "${f}" in
	( \"*\" ) f="${f#\"}" ; f="${f%\"}" ;;			# Remove quotes
	( * ) f="$(expand "${LM}${f}${RM}")" || return 1 ;;	# Try to expand variable
    esac
    test -n "${f}" || { err "empty filename set for 'include' directive" ; return 1 ; }
    f="$(search_inc "${f}")" || return 1
    eval_ret "$(process_file "${f}")"
}

# Process 'undef' directive
do_undef ()
{
    local var="$1"

    test -n "${var}" || { err "no parameters set for 'undef' directive" ; return 1 ; }
    check_vname "${var}" || return 1
    eval_ret "$(undef_var "${var}")"
}

# Process 'ifdef' directive
do_ifdef ()
{
    local var="$1"

    IFLVL=$(( IFLVL + 1 ))
    if test $P -eq 0 ; then
	test -n "${var}" || { err "no parameters set for 'ifdef' directive" ; return 1 ; }
	check_vname "${var}" || return 1
	eval "test \"X\" = \"\${V_${var}+X}\"" && P=0 || P=-${IFLVL}
    fi
    IFSTACK="${IFSTACK}|ifdef:${LN}"
}

# Process 'ifndef' directive
do_ifndef ()
{
    local var="$1"

    IFLVL=$(( IFLVL + 1 ))
    if test $P -eq 0 ; then
	test -n "${var}" || { err "no parameters set for 'ifndef' directive" ; return 1 ; }
	check_vname "${var}" || return 1
	eval "test \"X\" = \"\${V_${var}+X}\"" && P=-${IFLVL} || P=0
    fi
    IFSTACK="${IFSTACK}|ifndef:${LN}"
}

# Process 'elifdef' directive
do_elifdef ()
{
    local var="$1"

    case "$P" in
	( 0 | ${IFLVL} | -${IFLVL} )
	    case "${IFSTACK##*|}" in
		( '' ) err "'elifdef' without 'if'" ; return 1 ;;
		( "else"* ) err "'elifdef' after 'else'" ; return 1 ;;
	    esac
	    test -n "${var}" || { err "no parameters set for 'elifdef' directive" ; return 1 ; }
	    check_vname "${var}" || return 1
	    case "$P" in
		( 0 ) P=${IFLVL} ;;
		( -${IFLVL} ) eval "test \"X\" = \"\${V_${var}+X}\"" && P=0 ;;
	    esac ;;
    esac
    IFSTACK="${IFSTACK%|*}|elifdef:${LN}"
}

# Process 'elifndef' directive
do_elifndef ()
{
    local var="$1"

    case "$P" in
	( 0 | ${IFLVL} | -${IFLVL} )
	    case "${IFSTACK##*|}" in
		( '' ) err "'elifndef' without 'if'" ; return 1 ;;
		( "else"* ) err "'elifndef' after 'else'" ; return 1 ;;
	    esac
	    test -n "${var}" || { err "no parameters set for 'elifndef' directive" ; return 1 ; }
	    check_vname "${var}" || return 1
	    case "$P" in
		( 0 ) P=${IFLVL} ;;
		( -${IFLVL} ) eval "test \"X\" = \"\${V_${var}+X}\"" || P=0 ;;
	    esac ;;
    esac
    IFSTACK="${IFSTACK%|*}|elifndef:${LN}"
}

# Process 'else' directive
do_else ()
{
    case "$P" in
	( 0 | ${IFLVL} | -${IFLVL} )
	    case "${IFSTACK##*|}" in
		( '' ) err "'else' without 'if'" ; return 1 ;;
		( "else"* ) err "'else' after 'else'" ; return 1 ;;
	    esac
	    test -n "$1" && { err "extra parameters for 'else' directive" ; return 1 ; }
	    case "$P" in
		( 0 ) P=${IFLVL} ;;
		( -${IFLVL} ) P=0 ;;
	    esac ;;
    esac
    IFSTACK="${IFSTACK%|*}|else:${LN}"
}

# Process 'endif' directive
do_endif ()
{
    case "$P" in
	( 0 | ${IFLVL} | -${IFLVL} )
	    case "${IFSTACK}" in ( '' ) err "'endif' without 'if'" ; return 1 ;; esac
	    test -n "$1" && { err "extra parameters for 'endif' directive" ; return 1 ; }
	    P=0 ;;
    esac
    IFLVL=$(( IFLVL - 1 ))
    IFSTACK="${IFSTACK%|*}"
}

# Process 'error' directive
do_error ()
{
    local m="$1"

    case "${m}" in ( \"*\" ) m="${m#\"}" ; m="${m%\"}" ;; esac	# Remove quotes
    err "'error' directive: '${m}'"
    return 1
}

####

# Examine directive and call handler
do_directive ()
{
    local s="$(trim "${CURLINE#"${MAGIC}"}")"	# Cut 'magic' and trim spaces
    local d="${s%%[[:space:]]*}"		# Get directive
    local args="$(ltrim "${s#"${d}"}")"		# Get arguments

    case "${d}" in
	( '' | '#'* ) return 0 ;;	# Skip empty directives and comments
	( "ifdef" | "ifndef" | "elifdef" | "elifndef" | "else" | "endif" ) ;;
	( "define" | "error" | "include" | "undef" ) test $P -eq 0 || return 0 ;;
	( * ) test $P -eq 0 && { err "unknown directive '${d}'" ; return 1 ; } || return 0 ;;
    esac
    do_${d} "${args}"
}

# Expand variables
expand ()
{
    local s="$1"
    local h=""
    local t=""
    local v=""
    local u=""

    case "${s}" in
	( *"${LM}"*"${RM}"* )
	    h="${s%%"${LM}"*}" ; t="${s#*"${RM}"}"	# Get 'head' and 'tail'
	    v="${s%%"${RM}"*}" ; v="${v#*"${LM}"}"	# Get variable name
	    {
		check_vname "${v}"	&&		# Check variable name
		case "|${VS}|" in
		    ( *"|${v}|"* ) err "recursive expansion of variable '${v}'" ; false ;;
		esac			&&
		VS="${VS}|${v}"		&&		# Add to 'var stack'
		eval "u=\"\${V_${v}}\""	&&		# Expand variable to value
		case "${u}" in
		    ( *"${LM}"*"${RM}"* ) u="$(expand "${u}")" ;;	# Recursively expand value
		esac			&&
		VS="${VS%"|${v}"}"	&&		# Remove from 'var stack'
		case "${t}" in
		    ( *"${LM}"*"${RM}"* ) t="$(expand "${t}")" ;;	# Expand 'tail'
		esac
	    } || return 1
	    s="${h}${u}${t}"		# Construct expanded string
	    ;;
    esac
    printf "%s" "${s}"
}

# Output current line
output_line ()
{
    local s=""

    case "${CURLINE}" in
	( *"${LM}"*"${RM}"* )
	    s="$(expand "${CURLINE}")" && printf "%s\n" "${s}" >&3 || return 1 ;;
	( * ) printf "%s\n" "${CURLINE}" >&3 ;;
    esac
}

# Process line
process_line ()
{
    case "${CURLINE}" in
	( "${MAGIC}"* ) do_directive || return 1 ;;
	( * )
	    test $P -eq 0 || return 0
	    output_line || return 1 ;;
    esac
}

# Print error for unterminated directive
err_unterm ()
{
    local e="${IFSTACK##*|}"
    local d="${e%:*}"
    local l="${e#*:}"

    err "unterminated '${d}' directive at '${CURFILE:-<stdin>}':${l}"
}

# Process file (in subshell)
process_file ()
(
    local if="$1"	# Input file name
    local cf=""		# Canonical file name

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

    #  The main idea: since 'process_file' is executed in subshell we need
    #  the method of 'transfer' variables defined at 'down' subshell environment
    #  to the 'up' environment (see 'variable visibility scope' for subshells).
    #  This is used for 'define' and 'undef' directives to set or unset
    #  variables in included files and which must be visible at the 'global' level
    CURFILE="${if}"	# CURFILE (current file) is used by 'search_inc'
    IFLVL=0		# IFLVL (current 'if' stack level)
    IFSTACK=""		# IFSTACK ('if' stack) is used for nesting 'if...' directives
    LN=0		# LN (line number) contains current line number
    LVL=$(( ${LVL:-0} + 1 ))	# LVL (current level) is used for nesting control
    P=0			# P (process) is used as flag for conditional processing
    RET=""		# RET (return) is the string that should be passed to 'up' level
    # Read file line by line
    while IFS= read -r CURLINE ; do	# CURLINE (current line) is used as global buffer
	LN=$(( LN + 1 ))
	process_line || { err "in file '${if:-<stdin>}':${LN}" ; return 1 ; }
    done
    # Check for unterminated 'if...' directives
    test ${IFLVL} -eq 0 || { err_unterm ; return 1 ; }
    # 'Transfer' something to 'up' level if any
    test ${LVL} -gt 1 && printf "%s" "${RET}" || true
)

####

# Initialization subroutine
init ()
{
    set -o noglob	# Do not expand pathnames
    INCLIST=""		# List of include directories
    INFILE=""		# Input file (empty for 'stdin')
    LM="#{"		# Left (opening) marker for variables
    MAGIC="#%"		# 'Magic' string for directives
    OUTFILE=""		# Output file (empty for 'stdout')
    RM="}#"		# Right (closing) marker for variables
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
