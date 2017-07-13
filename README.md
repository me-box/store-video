# databox-store-hls-video

> Databox store for transcoding video and streaming as HLS.

A Databox store for storage of video files that transcodes uploaded videos
and makes them available as an [HLS](https://developer.apple.com/streaming/)
stream.

## Development setup

The store is built as a [Docker][docker] container. If you wish to
experiment without using the Docker install on your development machine, a
[Vagrant](https://www.vagrantup.com/) environment is also included which
contains a minimal environment with Docker installed.

## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

Third Party Component Licenses:

* ``tinycore/docker.tcz`` contains software from [Docker][docker]
  licensed under the [Apache 2.0 License][apache-2.0-license].
* ``tinycore/iptables.tcz`` contains software from [Netfilter][netfilter]
  licensed under the [GNU GPLv2 License][gplv2-license].

<https://github.com/me-box/store-video>

[docker]: https://www.docker.com/
[apache-2.0-license]: https://github.com/docker/docker/blob/master/LICENSE
[netfilter]: https://www.netfilter.org/
[gplv2-license]: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
