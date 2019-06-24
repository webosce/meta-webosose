# Copyright (c) 2018-2019 LG Electronics, Inc.

FILESEXTRAPATHS_prepend := "${THISDIR}/${BPN}:"

EXTENDPRAUTO_append = "webos6"

SRC_URI += " \
    file://0004-Support-WPS-PBC-and-PIN-mode.patch \
    file://0006-Fix-Unable-to-reconnect-to-same-Wi-Fi.patch \
    file://0007-Fix-for-wifi-network-switching-and-unable-to-connect.patch \
    file://0008-Multiple-wi-fi-networks-are-connected-via-WPS-PIN.patch \
"
