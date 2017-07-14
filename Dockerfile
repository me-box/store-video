FROM ocaml/opam:alpine
MAINTAINER dominic.price@nottingham.ac.uk
RUN sudo apk --no-cache add ffmpeg
ADD src /app/src
WORKDIR /app
RUN sudo chown -R opam:nogroup . \
    && opam switch create store-video 4.04.2 \
    && eval `opam config env` \
    && opam depext jbuilder \
    && opam install jbuilder \
    && jbuilder build src/store.exe
EXPOSE 8080
LABEL databox.type="store"
ENTRYPOINT ["/app/_build/default/src/store.exe"]
