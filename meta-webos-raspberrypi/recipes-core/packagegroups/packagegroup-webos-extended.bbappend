# Copyright (c) 2017-2018 LG Electronics, Inc.

# You don't need to change this value when you're changing just a RDEPENDS_${PN} variable.
EXTENDPRAUTO_append_rpi = "webosrpi2"

MEDIA = " \
    gstreamer1.0 \
    gstreamer1.0-libav \
    gstreamer1.0-omx \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    g-media-pipeline \
"
# Until build issues caused by PLAT-44962 are fixed in PLAT-45700
MEDIA_raspberrypi3-64 = ""

AISERVICE = " \
    com.webos.service.ai \
"

GPIOSERVICE = " \
    com.webos.service.rpi.gpio \
"
# There is only rpi-32bit keyword detection library available.(https://github.com/Kitt-AI/snowboy/tree/master/lib)
# It seems to be a library for arm-64bit(https://github.com/Kitt-AI/snowboy/tree/master/lib/aarch64-ubuntu1604),
# but it has not been verified on webOS rpi64 which cannot boot yet.
AISERVICE_raspberrypi3-64 = ""

RDEPENDS_${PN}_append_rpi = " \
    com.webos.service.audiooutput \
    ${MEDIA} \
    ${AISERVICE} \
    wiringpi \
    ${GPIOSERVICE} \
"
