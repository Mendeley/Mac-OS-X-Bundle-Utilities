OS X Bundle Utilities
=====================

This repository contains a set of utility scripts
related to packaging Qt applications under OS X.

### update-mac-bundle-lib-names.rb

update-mac-bundle-lib-names.rb is a script to replace
references to libraries in binaries in a Mac OS X bundle to refer
to copies of the libraries in the bundle instead of system-wide locations.

It was originally written for use with a Qt application to ensure that the application
in the bundle used the copies of the Qt libraries instead of copies installed to
system-wide locations.

See update-mac-bundle-lib-names.rb for more details and usage.

### hdiutil-codesign.rb

hdiutil-codesign.rb is a wrapper around the hdiutil command which
CPack uses to generate .dmg disk images for Mac applications.

In CPack's config file, set CPACK_COMMAND_HDIUTIL to point to this
wrapper script instead of hdiutil.

When CPack invokes this script with the path of a directory to
compress into a .dmg image, the wrapper script will first codesign
the contents of the app bundle in the directory and then
invoke the real hdiutil tool to create the .dmg image.
