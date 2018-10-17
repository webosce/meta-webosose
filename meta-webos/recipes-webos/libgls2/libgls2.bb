SUMMARY = "A GObject based library wrapping luna-service2"
AUTHOR = "Yi-Soo An <yisooan@gmail.com>"
SECTION = "webos/libs"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

DEPENDS = "luna-service2 glib-2.0 pmloglib"

WEBOS_VERSION = "0.1.0-1_6bcf4dd66c6965d29eb8f7dc364fbaa9a0415e09"
PR = "r0"

inherit webos_component
inherit webos_public_repo
inherit webos_enhanced_submissions
inherit webos_cmake
inherit webos_library

EXTRA_OECMAKE += "-DGLS2_BUILD_DOC:BOOL=FALSE"

SRC_URI = "${WEBOSOSE_GIT_REPO_COMPLETE}"
S = "${WORKDIR}/git"

