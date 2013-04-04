#!/usr/bin/env ruby

# change-lib-suffix.rb is a tool to alter a binary to change the path
# of imported libraries to use a given suffix, or remove the suffix.
#
# Whereas the DYLD_IMAGE_SUFFIX environment variable applies to all
# libraries a binary loads, this tool only applies to libraries whose
# paths match a given pattern.
#
# Example Usage:
#
# Given an app 'my-app' which links to '/usr/lib/MyLib.dylib':
#
#   change-lib-suffix.rb my-app MyLib _debug
#
# Would change 'my-app' to link to '/usr/lib/MyLib_debug.dylib' instead.
# This change can be reversed using:
#
#   change-lib-suffix.rb my-app MyLib
#
# The suffix must start with an underscore.  The section after the last underscore
# in the library's filename is assumed to be the current suffix.

require File.dirname(__FILE__) + "/common.rb"

binary = ARGV[0]
pattern = Regexp.new(ARGV[1])
suffix = ARGV[2] || ''

if !binary
	$stderr.puts "Binary to patch not specified"
	exit 1
end

if !ARGV[1]
	$stderr.puts "Library pattern to match not specified"
	exit 1
end

if !suffix.empty? && !suffix.start_with?('_')
	$stderr.puts "Replacement image suffix must be empty or must start with '_'"
	exit 1
end

deps = get_dependencies(binary)
deps.each do |dep|
	if dep =~ pattern
		path_without_suffix = dep
		suffix_pos = dep.rindex('_')
		if suffix_pos
			path_without_suffix = dep[0..suffix_pos - 1]
		end
		new_lib_path = path_without_suffix + suffix

		if new_lib_path != dep
			puts "Changing lib path #{dep} to #{new_lib_path}"
			if !system("install_name_tool", "-change", dep, new_lib_path, binary)
				$stderr.puts "Unable to change install name for #{dep}"
			end
		end
	end
end
