# Copyright (c) 2018 LG Electronics, Inc.

FILESEXTRAPATHS_prepend := "${THISDIR}/${BPN}:"

EXTENDPRAUTO_append = "webos4"

SRC_URI += " \
    file://0004-Support-WPS-PBC-and-PIN-mode.patch \
    file://0005-Fix-for-connection-lost-issue-for-setipv6-API.patch \
    file://0006-Fix-Unable-to-reconnect-to-same-Wi-Fi.patch \
"
