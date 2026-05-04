#!/bin/sh
set -e
# Requires Theos + iOS SDK + ldid on macOS/Linux.
# Example:
#   export THEOS=~/theos
#   make package
#   ./package_ipa.sh .theos/obj/debug/XXTWakeHelper.app
make clean
make
./package_ipa.sh .theos/obj/debug/XXTWakeHelper.app
