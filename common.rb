# Return an array listing the dependencies of 'lib_path'
# (as returned by 'otool -L $LIB_PATH')
def get_dependencies(lib_path)
	deps = []
	entry_name_regex = /(.*)\(compatibility version.*\)/
	`otool -L '#{lib_path}'`.strip.split("\n").each do |entry|
		match = entry_name_regex.match(entry)
		if (match)
			dep_path = match[1].strip

			# Note - otool lists dependencies separately for each architecture
			# in a universal binary - only return the unique paths
			deps << dep_path if !deps.include?(dep_path)
		end
	end
	return deps
end
