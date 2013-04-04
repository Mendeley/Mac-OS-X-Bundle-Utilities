#!/usr/bin/ruby

# This script replaces references to libraries in binaries in a Mac OS X
# bundle to refer to copies of the libraries in the bundle instead of
# in system-wide locations.
#
# eg. If Contents/MacOS/MyApp references libfoo.dylib which is located
# in Contents/Resources/libfoo.dylib, this tool would change the install name
# of libfoo.dylib to @executable_path/../Resources/libfoo.dylib and update
# the shared library reference in MyApp to match.
#
# This script will fail with an error if copies of any non-system libraries referenced
# by binaries in the bundle are not found within the bundle.
#
# Usage:
#
# update-mac-bundle-lib-names.rb [options] <bundle dir>
#

require 'optparse'
require 'pathname'

require File.dirname(__FILE__) + "/common.rb"

BUNDLE_MAIN_EXE_PATH = "Contents/MacOS"

def is_system_lib(lib_path)
	return lib_path =~ /^\/System/ ||
	       lib_path =~ /^\/usr\/lib/
end

def install_name_needs_fixup?(lib)
	return !lib.include?("@executable_path")
end

# returns the path of 'binary' relative to the executable path
# within the binary
def get_bundle_install_name(bundle_dir, binary)
	current_dir = "#{bundle_dir}/#{BUNDLE_MAIN_EXE_PATH}"
	relative_path = Pathname.new(binary).relative_path_from(Pathname.new(current_dir)).to_s
	relative_path = "@executable_path/#{relative_path}"
	return relative_path
end

# returns the path to the root of the bundle containing 'binary'
def containing_bundle_path(binary)
	dir = File.dirname(binary)
	while !dir.end_with?('.app') && dir != '/'
		dir = File.dirname(dir)
	end
	return dir
end

def find_binaries(bundle_path)
	binaries = []
	`find -H "#{bundle_path}" -type f`.each do |binary|
		binary = binary.strip
		object_name = `otool -D "#{binary}"`
		if (!object_name.include?("is not an object file"))
			binaries << binary
		end
	end
	return binaries
end

def read_install_name(path)
	`otool -X -D "#{path}"`.each_line do |line|
		return line.strip
	end
	return nil
end

def run_cmd(dry_run,verbose,command)
	if (verbose)
		puts command
	end
	if (!dry_run)
		if (!system(command))
			raise "Failed to run: #{command}"
		end
	end
end

dry_run = false
verbose = false

OptionParser.new do |parser|
	parser.banner = <<END
Change the library install names referenced by binaries within a Mac OS X bundle
to reference copies of the library within the bundle.
END
	parser.on("-v","--verbose","Print details of install name changes") do
		verbose = true
	end
	parser.on("-d","--dry-run","Do not actually perform the install name changes") do
		dry_run = true
	end
end.parse!

# find all binaries in the bundle
bundle_dir = ARGV[0]
binaries = find_binaries(bundle_dir)
binary_paths = {}

# |install_name_path_map| maps from current install name of a binary
# to the path to that binary within the bundle.
install_name_path_map = {}

# first pass - update the install names of each shared library
# in the bundle to be relative to the Contents/MacOS directory
binaries.each do |binary|
	current_install_name = read_install_name(binary)
	if (current_install_name &&
	    install_name_needs_fixup?(current_install_name))
		new_install_name = get_bundle_install_name(bundle_dir,binary)
		run_cmd(dry_run,verbose,"install_name_tool -id \"#{new_install_name}\" \"#{binary}\"")
		install_name_path_map[current_install_name] = binary
	end
end

# second pass - update the install names referenced by each executable
# or shared library to use the executable-relative paths determined in
# the first pass
binaries.each do |binary|
	deps = get_dependencies(binary)
	deps.each do |dep|
		# do not try to look for copies of system libraries inside the bundle
		next if is_system_lib(dep)

		if (install_name_needs_fixup?(dep))
			if (!install_name_path_map.include?(dep))
				raise "Library '#{dep}' referenced by '#{binary}' not found in bundle."
			end

			# get the relative path from the directory containing the binary
			# to the dependency.
			dep_bundle_path = install_name_path_map[dep]
			binary_path = File.dirname(binary)
			rel_path = Pathname.new(dep_bundle_path).relative_path_from(Pathname.new(binary_path)).to_s

			# @loader_path is replaced at runtime with the path to the binary
			# see http://www.mikeash.com/pyblog/friday-qa-2009-11-06-linking-and-install-names.html
			# for an explanation.
			install_name = "@loader_path/#{rel_path}"
			run_cmd(dry_run,verbose,"install_name_tool -change \"#{dep}\" \"#{install_name}\" \"#{binary}\"")
		end
	end
end

