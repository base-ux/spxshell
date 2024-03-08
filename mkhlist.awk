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

# Skip comments and empty lines
$0 ~ /^(#|[[:space:]]*$)/ { next }

# Otherwise process the line
{
    item = $1
    list = $2

    # Remove leading and trailing spaces
    sub(/^[[:space:]]+/, "", item)
    sub(/[[:space:]]+$/, "", item)
    if ( list ~ /^[[:space:]]*$/ ) {
	# If list is empty
	n = 0
    } else {
	# Split list to the items
	n = split(list, alist, ",")
	# Remove leading and trailing spaces
	for ( i = 1; i <= n; i++ ) {
	    sub(/^[[:space:]]+/, "", alist[i])
	    sub(/[[:space:]]+$/, "", alist[i])
	}
    }
    if ( item ~ /^%/ ) {
	# If item is group (begin with %)
	# Remove leading % and any spaces after it
	sub(/^%[[:space:]]*/, "", item)
	# Construct lst-file name
	f_lst = OUT_DIR "/" item ".lst"
	for ( i = 1; i <= n; i++ ) {
	    s = alist[i]
	    # If list item is group then add .lst-suffix
	    if ( s ~ /^%/ ) s = s ".lst"
	    write_lst(s, f_lst)
	}
    } else {
	# If item is ordinary host
	if ( n == 0 ) {
	    # Construct lst-file name
	    # For empty lists write to nogroup.lst file
	    f_lst = OUT_DIR "/nogroup.lst"
	    write_lst(item, f_lst)
	} else {
	    for ( i = 1; i <= n; i++ ) {
		s = alist[i]
		# Ignore groups in the list for ordinary items
		if ( s ~ /^%/ ) continue
		# Construct lst-file name
		f_lst = OUT_DIR "/" s ".lst"
		write_lst(item, f_lst)
	    }
	}
    }
}
