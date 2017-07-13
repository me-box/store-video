FROM ocaml/opam:alpine

MAINTAINER dominic.price@nottingham.ac.uk

ADD src /app/src
WORKDIR /app
RUN sudo chown -R opam:nogroup .
RUN opam switch 4.04.2
RUN opam depext jbuilder
RUN opam install jbuilder
RUN eval `opam config env` \
    && jbuilder build src/store.exe

EXPOSE 8080

LABEL databox.type="store"

ENTRYPOINT ["/app/_build/default/src/store.exe"]
