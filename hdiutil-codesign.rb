#!/usr/bin/env ruby

require 'fileutils'
require 'find'

# This is a wrapper script around 'hdiutil' which can be used to ensure
# that a Mac OS bundle's contents are code-signed before the .dmg is created using 'hdiutil create'
#
# To use this script, in packaging config file for CPack, set
# CPACK_COMMAND_HDIUTIL to the path to this script and set the
# bundle name and code signing identity appropriately.
#
# We wrap 'hdiutil create' so that we can be sure that the bundle's contents
# have been fully prepared before running the code-signing step, since any alterations
# to the bundle's contents after code signing will cause verification to fail.

BUNDLE_NAME = "Mendeley Desktop.app"
CODESIGN_IDENTITY = "Developer ID Application: Mendeley Ltd."

CODESIGN_KEYCHAIN_VAR = 'MENDELEY_CODESIGN_KEYCHAIN'
CODESIGN_KEYCHAIN_PASS_VAR = 'MENDELEY_CODESIGN_KEYCHAIN_PASS'

if !ENV[CODESIGN_KEYCHAIN_VAR] || !ENV[CODESIGN_KEYCHAIN_PASS_VAR]
	$stderr.puts <<END
Unable to unlock keychain for code signing.  The #{CODESIGN_KEYCHAIN_VAR} or #{CODESIGN_KEYCHAIN_PASS_VAR} variables are not set."
END
	exit 1
end

# Fix up Qt framework bundles to conform to the bundle structure described
# at https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html
#
# See also: https://bugreports.qt-project.org/browse/QTBUG-23268
def fixup_framework_bundle(framework_path)
	# ensure the Resources directory exists under Versions/Current
	# and that it contains an Info.plist file.
	#
	# When the Qt 4 framework bundles are built, the Info.plist file
	# is incorrectly placed in Contents/Info.plist, so move it if necessary
	content_plist = "#{framework_path}/Contents/Info.plist"
	resource_dir = "#{framework_path}/Resources"
	resource_plist = "#{resource_dir}/Info.plist"

	FileUtils.mkpath "#{framework_path}/Versions/Current/Resources"
	FileUtils.ln_sf 'Versions/Current/Resources', "#{framework_path}/Resources"

	if File.exist?(content_plist) && !File.exist?(resource_plist)
		FileUtils.cp content_plist, resource_plist
	end

	# Remove anything from the root of the bundle which is not a symlink
	# or the 'Versions' directory - see link above to Apple's documentation
	# on the structure of framework bundles
	Dir.foreach(framework_path) do |entry|
		next if entry == '.' || entry == '..'

		file_info = File.lstat("#{framework_path}/#{entry}")

		if entry != 'Versions' && file_info.ftype != 'link'
			$stderr.puts "Removing unexpected entry from framework bundle root #{framework_path}/#{entry}"
			FileUtils.rm_rf "#{framework_path}/#{entry}"
		end
	end
end

def codesign_bundle(src_dir)
	puts "Signing bundle #{src_dir}"

	# Attempt to unlock the keychain using the 'security' tool so that 'codesign' does
	# not prompt for user interaction
	if !system("security unlock-keychain -p '#{ENV[CODESIGN_KEYCHAIN_PASS_VAR]}' #{ENV[CODESIGN_KEYCHAIN_VAR]}")
		$stderr.puts "Error signing bundle - Unlocking keychain failed"
		exit 1
	end

	# Work around an issue where the Qt framework bundles are not correctly
	# structured under Qt 4.
	#
	# - There should only be one real top-level folder, 'Versions' with
	#   a symlink for the main lib: 'QtModule -> Versions/Current/QtModule' and
	#   the Resources folder 'Resources -> Versions/Current/Resourcs'
	#
	# - There must be an Info.plist file in the Resources/ folder
	#
	# See http://stackoverflow.com/a/18149893/434243
	#
	Find.find(src_dir).select { |path| path.end_with?('.framework') }.each do |framework_path|
		fixup_framework_bundle framework_path
	end

	if !system('codesign',  '--deep', '--force', '--sign', CODESIGN_IDENTITY, src_dir)
		$stderr.puts "Error signing bundle"
		exit 1
	end
end

# Check if this is the initial command to create the .DMG image and if so,
# codesign the bundle's contents first
if ARGV[0] == "create"
	ARGV.each_with_index do |arg,index|
		if arg == "-srcfolder"
			codesign_bundle ARGV[index+1] + '/' + BUNDLE_NAME
		end
	end
end

# Invoke the real hdiutil utility
system "hdiutil", *ARGV
