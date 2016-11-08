#!/usr/bin/env python
# encoding: utf-8

import os.path
import rpm
import sys

def get_rpm_hdr(rpm_file):
	""" Возращаем заголовок пакета RPM """
	ts = rpm.ts()
	ts.setVSFlags(-1)
	fdno = os.open(rpm_file, os.O_RDONLY)
	try:
		hdr = ts.hdrFromFdno(fdno)
	except rpm.error:
		fdno = os.open(rpm_file, os.O_RDONLY)
		ts.setVSFlags(rpm._RPMVSF_NOSIGNATURES)
		hdr = ts.hdrFromFdno(fdno)
	os.close(fdno)
	return hdr

def get_rpm_hdr(rpm_file):
	""" Возращаем заголовок пакета RPM """
	ts = rpm.ts()
	ts.setVSFlags(-1)
	fdno = os.open(rpm_file, os.O_RDONLY)
	try:
		hdr = ts.hdrFromFdno(fdno)
	except rpm.error:
		fdno = os.open(rpm_file, os.O_RDONLY)
		ts.setVSFlags(rpm._RPMVSF_NOSIGNATURES)
		hdr = ts.hdrFromFdno(fdno)
	os.close(fdno)
	return hdr

def main():
	hdr = get_rpm_hdr(sys.argv[1])
	pkg_name = hdr[rpm.RPMTAG_NAME]
	pkg_version = hdr[rpm.RPMTAG_VERSION]
	pkg_release = hdr[rpm.RPMTAG_RELEASE]
	#print "%s %s %s" % (pkg_name, pkg_version, pkg_release)
	sys.stdout.write("%s %s %s" % (pkg_name, pkg_version, pkg_release))
	sys.stdout.flush()
	sys.exit(0)

if __name__ == '__main__': 
    main()