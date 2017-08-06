type t

type video

type put_error =
  | Out_of_bounds

val create :
    raw_dir:string -> transcoded_dir:string
    -> metadata_dir:string -> Hls_transcoder.encoding_options list -> t Lwt.t

val init_video : t -> Types.Metadata_t.t -> video Lwt.t

val put_data : video -> Lwt_bytes.t -> int -> (unit, put_error) result Lwt.t

val finalize : video -> unit Lwt.t
