# databox-store-hls-video
> Databox store for transcoding video and streaming as HLS.

A Databox store for storage of video files that transcodes uploaded videos
and makes them available as an [HLS](https://developer.apple.com/streaming/)
stream.

## Development setup

There are two routes available to development. The first is via
[Vagrant](https://www.vagrantup.com/) which will set up a complete development
environment. If you do not wish to use Vagrant, you will need [Docker][docker]
installed.

In order to build, run ``./build.sh`` to build the Docker container for
x86 platforms, ``./build.sh arm`` to build for Arm on Arm or
``./build.sh xbuild`` to build for Arm on x86. The environment variable
``DOCKER_OPTS`` can be used to provide extra command line arguments to the
Docker command, for example for building on a remote host.

## Meta

Distributed under the ISC license. See ``LICENSE`` for more information.

Third Party Component Licenses:
* ``tinycore/docker.tcz`` contains software from [Docker][docker]
licensed under the [Apache 2.0 License][apache-2.0-license].
* ``tinycore/iptables.tcz`` contains software from [Netfilter][netfilter]
licensed under the [GNU GPLv2 License][gplv2-license].

<https://github.com/me-box/databox-store-hls-video>

[docker]: https://www.docker.com/
[apache-2.0-license]: https://github.com/docker/docker/blob/master/LICENSE
[netfilter]: https://www.netfilter.org/
[gplv2-license]: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
