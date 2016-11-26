FROM scratch
LABEL databox.type="store"
COPY store.native /store.native
COPY ffmpeg /ffmpeg
ENTRYPOINT [ "/store.native" ]
EXPOSE 8080
