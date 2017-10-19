FROM ocaml/opam:alpine
MAINTAINER dominic.price@nottingham.ac.uk
RUN sudo apk --no-cache add ffmpeg
ADD src /app/src
WORKDIR /app
RUN sudo chown -R opam:nogroup . \
    && opam switch 4.04.2 \
    && eval `opam config env` \
    && opam depext jbuilder lwt logs atdgen uuidm ezirmin \
    && opam install jbuilder lwt logs atdgen uuidm ezirmin
RUN eval `opam config env` \
    && jbuilder build src/store.exe
EXPOSE 8080
LABEL databox.type="store"
ENTRYPOINT ["/app/_build/default/src/store.exe"]
