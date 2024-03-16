# Write item to lst-file
function write_lst (item, file) {
    dir = file
    # Remove file name (dirname)
    sub(/\/[^\/]*$/, "", dir)
    if ( dir in dirs ) { ; } else {
	# If dir is not in list then create it
	dirs[dir] = "true"
	cmd = "test -d '" dir "' || mkdir -p '" dir "'"
	system(cmd)
    }
    # Write item to file
    print item >> file
}

# Skip comments, empty lines, groups and items
$1 ~ /^[[:space:]]*(#|(%[[:space:]]*)?$)/ { next }
# Remove inline comments
$0 ~ /#/ { sub(/[[:space:]]*#.*$/, "", $0) }

# Otherwise process the line
{
    item = $1
    list = $2

    # Process list
    if ( list ~ /^[[:space:]]*$/ ) {
	# If list is empty
	n = 0
    } else {
	# Split list to the items
	n = split(list, alist, ",")
	for ( i = 1; i <= n; i++ ) {
	    # Remove leading and trailing spaces
	    sub(/^[[:space:]]+/, "", alist[i])
	    sub(/[[:space:]]+$/, "", alist[i])
	}
    }

    # Process item
    # Remove leading and trailing spaces for item
    sub(/^[[:space:]]+/, "", item)
    sub(/[[:space:]]+$/, "", item)
    if ( item ~ /^%/ ) {
	# If item is group (begin with %)
	# Remove leading % and any spaces after it
	sub(/^%[[:space:]]*/, "", item)
	# Construct listfile name
	f_lst = OUT_DIR "/" item
	for ( i = 1; i <= n; i++ ) {
	    s = alist[i]
	    # Ignore empty records
	    if ( s ~ /^%?$/ ) continue
	    write_lst(s, f_lst)
	}
    } else {
	# If item is ordinary host
	w = 0
	for ( i = 1; i <= n; i++ ) {
	    s = alist[i]
	    # Ignore groups, empty records
	    # and records which begin or end with '/'
	    if ( s ~ /^(%|\/|$)|\/$/ ) continue
	    # Construct listfile name
	    f_lst = OUT_DIR "/" s
	    write_lst(item, f_lst)
	    w++
	}
	if ( w == 0 ) {
	    # For empty lists write to 'nogroup' file
	    f_lst = OUT_DIR "/nogroup"
	    write_lst(item, f_lst)
	}
    }
}
