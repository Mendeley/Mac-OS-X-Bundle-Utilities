#!/usr/bin/env ruby

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

# Check if this is the initial command to create the .DMG image and if so,
# codesign the bundle's contents first
if ARGV[0] == "create"
	ARGV.each_with_index do |arg,index|
		if arg == "-srcfolder"
			# Attempt to unlock the keychain using the 'security' tool so that 'codesign' does
			# not prompt for user interaction
			if !system("security unlock-keychain -p '#{ENV[CODESIGN_KEYCHAIN_PASS_VAR]}' #{ENV[CODESIGN_KEYCHAIN_VAR]}")
				$stderr.puts "Error signing bundle - Unlocking keychain failed"
				exit 1
			end

			src_dir = ARGV[index+1] + '/' + BUNDLE_NAME
			if !system("codesign -f -s '#{CODESIGN_IDENTITY}' \"#{src_dir}\"")
				$stderr.puts "Error signing bundle"
				exit 1
			end
		end
	end
	
end

# Invoke the real hdiutil utility
system "hdiutil", *ARGV
