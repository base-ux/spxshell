#!/bin/sh

# Unset all aliases
'unalias' -a

# Ensure 'command' is not a user function
unset -f command

# Use shell dependent 'local' definition
local="$(command -v local)"
test -z "${local}" && local="$(command -v typeset)"
alias local="${local}"

# Program name
PROG="$(basename -- "$0")"

# Print error message
err ()
{
    printf "%s: error: %s\n" "${PROG}" "$*" >&2
}

# Print usage information
usage ()
{
    cat << EOF
Usage: ${PROG} file
EOF
}

# Process '#%shebang' directive
do_shebang ()
{
    local _file="$1"
    local _line="$2"

    case "${_line}" in
	( *[[:space:]][![:space:]]* )
	    err "no parameters allowed for '#%shebang' directive"
	    return 1
	    ;;
    esac
    printf "#!/bin/sh\n"	# The only option for now
}

# Process '#%prolog' directive
do_prolog ()
{
    local _file="$1"
    local _line="$2"
    local _f=""

    case "${_line}" in
	( *[[:space:]][![:space:]]* )
	    err "no parameters allowed for '#%prolog' directive"
	    return 1
	    ;;
    esac
    _f="$(absolute_path "sys/prolog" "${_file%/*}")"
    if test -f "${_f}" ; then
	process_file "${_f}"
    else
	embed_prolog
    fi
}

# Embedded prolog code
embed_prolog ()
{
    cat << 'EOF'
### Prolog

# Unset all aliases
'unalias' -a

# Ensure 'command' is not a user function
unset -f command

# Use shell dependent 'local' definition
local="$(command -v local)"
test -z "${local}" && local="$(command -v typeset)"
alias local="${local}"

# Program name
PROG="$(basename -- "$0")"

### Prolog end
EOF
}

# Process '#%include' directive
do_include ()
{
    local _file="$1"
    local _line="$2"
    local _f=""

    set -- ${_line##'#%include'}
    if test $# -eq 0 ; then
	err "no parameters set for '#%include' directive"
	return 1
    fi
    for _f in "$@" ; do
	{
	    _f="$(absolute_path "${_f}" "${_file%/*}")"	&&
	    check_file "${_f}"	&&
	    process_file "${_f}"
	} || return 1
    done
}

# Examine directive and call handler
do_directive ()
{
    local _file="$1"
    local _line="$2"

    case "${_line}" in
	( '#%shebang' | '#%shebang'[[:space:]]* )
	    do_shebang "${_file}" "${_line}" || return 1 ;;
	( '#%prolog'  | '#%prolog'[[:space:]]*  )
	    do_prolog  "${_file}" "${_line}" || return 1 ;;
	( '#%include' | '#%include'[[:space:]]* )
	    do_include "${_file}" "${_line}" || return 1 ;;
	( * )
	    err "unknown directive '${_line%%[[:space:]]*}'"
	    return 1
	    ;;
    esac
}

# Read file
read_file ()
{
    local _file="$1"
    local _ln=0
    local _line=""
    local _rc

    test -n "${_file}" || return 1
    while IFS= read -r _line ; do
	_ln="$(( ${_ln} + 1 ))"
	case "${_line}" in
	    ( '#%'* )
		do_directive "${_file}" "${_line}" || {
		    err "processing error in file '${_file}' at line ${_ln}"
		    return 1
		} ;;
	    ( * ) printf "%s\n" "${_line}" ;;
	esac
    done < "${_file}"
}

# Print absolute path
absolute_path ()
{
    local _path="$1"
    local _base="$2"
    local _cwd="$(pwd)"

    test -n "${_path}" || return 1
    case "${_base}" in
	( /* ) ;;
	(  * ) _base="${_cwd%/}/${_base}" ;;
    esac
    case "${_path}" in
	( /* ) ;;
	(  * ) _path="${_base%/}/${_path}" ;;
    esac
    printf "%s" "${_path}"
}

# Print canonical path
canonical_path ()
{
    local _path="$1"
    local _d="${_path%/*}"
    local _f="${_path##*/}"

    test -n "${_path}" || return 1
    _d="$(cd -P -- "${_d:-/}" ; pwd)"
    printf "%s" "${_d}/${_f}"
}

# Check file
check_file ()
{
    local _file="$1"

    test -n "${_file}" || return 1
    if ! test -f "${_file}" ; then
	err "file '${_file}' not found"
	return 1
    fi
    if ! test -r "${_file}" ; then
	err "can't open file '${_file}'"
	return 1
    fi
}

# Process file (execute in subshell)
process_file ()
(
    local _file="$1"
    local _cfile=""

    # Add canonical file name to stack (for cyclic include determination)
    _cfile="$(canonical_path "${_file}")" || return 1
    case " ${FSTACK} " in
	( *" ${_cfile} "* )
	    err "cyclic include of file '${_file}'"
	    return 1
	    ;;
	( * ) FSTACK="${FSTACK:+"${FSTACK} "}${_cfile}" ;;
    esac

    # Read file
    read_file "${_file}" || return 1

    # Remove from file names stack
    FSTACK="${FSTACK%"${_cfile}"*}"
    FSTACK="${FSTACK%" "*}"	# Remove trailing space
)

# Main subroutine
main ()
{
    local _file=""

    test $# -eq 1 || { usage ; return 1 ; }
    {
	_file="$(absolute_path "$1")"	&&
	check_file "${_file}"		&&
	process_file "${_file}"
    } || return 1
}

# Call main subroutine
main "$@"
