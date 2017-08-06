(*
  /<root>
  |_> /<root>/<raw_dir>
    |_> <uuid>
  |_> /<root>/<transcoded_dir>/<uuid>
    |_> index.m3u8 etc.
  |_> /<root>/<irmin_dir>/<uuid>
    |_> <metadata.json>
    |_> <status.json>

 *)

type t = {
  raw_dir : string;
  transcoded_dir : string;
  metadata_dir : string;
  random_state : Random.State.t;
  encoding_options : Hls_transcoder.encoding_options list;
  transcoder : Hls_transcoder.t;
}

type video = {
  t : t;
  id : Uuidm.t;
  raw_file : string;
  metadata : Types.Metadata_t.t;
  status : Types.Status_t.t ref;
}

type put_error =
  | Out_of_bounds

let create ~raw_dir ~transcoded_dir ~metadata_dir encoding_options =
  let open Lwt in
  Hls_transcoder.create () >>= fun transcoder ->
  {
    raw_dir = raw_dir;
    transcoded_dir = transcoded_dir;
    metadata_dir = metadata_dir;
    random_state = Random.State.make_self_init ();
    encoding_options = encoding_options;
    transcoder = transcoder;
  } |> return

let init_video t metadata =
  let open Lwt in
  let uuid = Uuidm.v4_gen t.random_state () in
  let file = Filename.concat t.raw_dir (Uuidm.to_string uuid) in
  Lwt_unix.openfile file [Unix.O_CREAT] 0o644 >>= fun fd ->
  Lwt_unix.close fd >>= fun _ ->
  Lwt_unix.truncate file Types.Metadata_j.(metadata.size) >>= fun _ ->
  {
    t = t;
    id = uuid;
    raw_file = file;
    metadata = metadata;
    status = ref (Types.Status_t.Created);
  } |> return

let put_data video data start =
  let open Lwt in
  Lwt_unix.openfile video.raw_file [Lwt_unix.O_WRONLY] 0o644 >>= fun fd ->
  Lwt_unix.write fd (Lwt_bytes.to_bytes data)
      start (Lwt_bytes.length data) >>= fun _ ->
  Ok () |> Lwt.return

let finalize video =
  let open Lwt in
  let uuid_s = Uuidm.to_string video.id in
  let file = Filename.concat video.t.raw_dir uuid_s in
  let dir = Filename.concat video.t.transcoded_dir uuid_s in
  Lwt_unix.mkdir dir 0o755 >>= fun _ ->
  video.status := Types.Status_t.Finilized;
  Hls_transcoder.schedule video.t.transcoder file dir video.t.encoding_options
      (function
      | Ok log ->
        video.status := Types.Status_t.Transcoded;
        return_unit
      | Error (log, status) ->
        video.status := Types.Status_t.Transcoding_failed (log, status);
        return_unit)
