SUMMARY = "GPIO service for WebOS RPI"
AUTHOR = "Joonho Ryu <ruujoon93@gmail.com>"
SECTION = "webos/extended-service"
LICENSE = "Apache-2.0"

LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

DEPENDS= "glib-2.0 json-c wiringpi pmloglib luna-service2"

inherit webos_component
inherit webos_cmake
inherit webos_system_bus
inherit webos_public_repo
inherit webos_enhanced_submissions

WEBOS_VERSION = "1.0.0-2_adec5b1e3c9062a4642daf0e9f37bdead7433a90"
PR = "r0"

SRC_URI = "${WEBOSOSE_GIT_REPO_COMPLETE}"
S = "${WORKDIR}/git"
