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
    local _line="$1"

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
    local _line="$1"

    case "${_line}" in
	( *[[:space:]][![:space:]]* )
	    err "no parameters allowed for '#%prolog' directive"
	    return 1
	    ;;
    esac
    embed_prolog
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
    local _line="$1"
    local _f=""

    set -- ${_line##'#%include'}
    if test $# -eq 0 ; then
	err "no parameters set for '#%include' directive"
	return 1
    fi
    for _f ; do
	process_file "${_f}" || return 1
    done
}

# Examine directive and call handler
do_directive ()
{
    local _line="$1"

    case "${_line}" in
	( '#%shebang' | '#%shebang'[[:space:]]* )
	    do_shebang "${_line}" || return 1 ;;
	( '#%prolog'  | '#%prolog'[[:space:]]*  )
	    do_prolog  "${_line}" || return 1 ;;
	( '#%include' | '#%include'[[:space:]]* )
	    do_include "${_line}" || return 1 ;;
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
		do_directive "${_line}" || {
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
    local _cwd="$(pwd)"

    test -n "${_path}" || return 1
    case "${_path}" in
	( /* ) ;;
	(  * ) _path="${_cwd%/}/${_path}" ;;
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

    {
	_file="$(absolute_path "${_file}")"	&&
	check_file "${_file}"			&&
	_cfile="$(canonical_path "${_file}")"
    } || return 1

    # Add to filenames stack
    case " ${FSTACK} " in
	( *" ${_cfile} "* )
	    err "cyclic include of file '${_file}'"
	    return 1
	    ;;
	( * ) FSTACK="${FSTACK:+"${FSTACK} "}${_cfile}" ;;
    esac

    # Read file
    read_file "${_file}" || return 1

    # Remove from filenames stack
    FSTACK="${FSTACK%"${_cfile}"*}"
    FSTACK="${FSTACK%" "*}"	# Remove trailing space
)

# Main subroutine
main ()
{
    test $# -eq 1 || { usage ; return 1 ; }
    process_file "$1"
}

# Call main subroutine
main "$@"
