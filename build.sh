#!/bin/sh

NAME=databox-store-hls-video
EXECUTABLE=store.native
FFMPEG=ffmpeg
DOCKER="docker ${DOCKER_OPTS}"
BUILDFILE_EXT=x86
TARGET=latest

case $1 in
"arm")
  TARGET=arm
  BUILDFILE_EXT=arm
;;
"xbuild")
  TARGET=arm
  BUILDFILE_EXT=arm-xbuild
;;
*)
  TARGET=latest
  BUILDFILE_EXT=x86
;;
esac

${DOCKER} build -f Dockerfile.${BUILDFILE_EXT}.build \
    -t ${NAME}:${BUILDFILE_EXT} . \
  && CONTAINER=`${DOCKER} create ${NAME}:${BUILDFILE_EXT}` \
  && ${DOCKER} cp ${CONTAINER}:/app/_build/src/store/${EXECUTABLE} . \
  && ${DOCKER} cp ${CONTAINER}:/usr/local/bin/${FFMPEG} . \
  && ${DOCKER} rm ${CONTAINER} \
  && ${DOCKER} build --no-cache=true -t ${NAME}:${TARGET} . \
  && rm -f ${EXECUTABLE} ${FFMPEG}
