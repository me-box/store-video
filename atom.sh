#!/bin/sh

NAME="databox-store-hls-video"

if [ "$1" = "rebuild" ]; then
  if [ -n "`docker ps -a | grep atom-$NAME`" ]; then
    docker rm --force atom-$NAME
  fi
  if [ -n "`docker images | grep atom-$NAME`" ]; then
    docker rmi atom-$NAME
  fi
fi

if [ -z "`docker images | grep atom-$NAME`" ]; then
  docker build -t atom-$NAME -f Dockerfile.atom .
fi

if [ -z "`docker ps -a | grep atom-$NAME`" ]; then
  docker run -ti --env=DISPLAY \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      -v /dev/shm:/dev/shm \
      -v `pwd`/src:/home/atom/$NAME/src \
      -v `pwd`/test:/home/atom/$NAME/test \
      -v `pwd`/.merlin:/home/atom/$NAME/.merlin \
      -v `pwd`/_oasis:/home/atom/$NAME/_oasis \
      --network=host \
      --privileged \
      --name atom-$NAME \
      atom-$NAME
else
  docker start -ai atom-$NAME
fi
