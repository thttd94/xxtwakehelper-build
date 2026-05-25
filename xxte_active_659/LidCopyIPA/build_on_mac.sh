#!/bin/sh
set -e
make clean
make
./package_ipa.sh .theos/obj/debug/LidCopy.app
