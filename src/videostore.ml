module Store = Ezirmin.FS_lww_register(Irmin.Contents.String)

type t = {
  raw_dir : string;
  transcoded_dir : string;
  metadata_dir : string;
  random_state : Random.State.t;
  encoding_options : Hls_transcoder.encoding_options list;
  transcoder : Hls_transcoder.t;
  store : Store.branch;
}

module Video = struct

  type vs = t

  type t = {
    videostore : vs;
    id : Uuidm.t;

  }

end

type video = {
  t : t;
  id : Uuidm.t;
  raw_file : string;
}

type put_error =
  | Out_of_bounds

let create ~raw_dir ~transcoded_dir ~metadata_dir encoding_options =
  let open Lwt in
  Hls_transcoder.create () >>= fun transcoder ->
  Store.init ~root:metadata_dir ~bare:true () >>= Store.master >>= fun store ->
  {
    raw_dir = raw_dir;
    transcoded_dir = transcoded_dir;
    metadata_dir = metadata_dir;
    random_state = Random.State.make_self_init ();
    encoding_options = encoding_options;
    transcoder = transcoder;
    store = store;
  } |> return

let init_video t metadata =
  let open Lwt in
  let uuid = Uuidm.v4_gen t.random_state () in
  let file = Filename.concat t.raw_dir (Uuidm.to_string uuid) in
  Lwt_unix.openfile file [Unix.O_CREAT] 0o644 >>= fun fd ->
  Lwt_unix.close fd >>= fun _ ->
  let uuid_s = Uuidm.to_string uuid in
  Store.write t.store ~path:[uuid_s; "metadata"]
      (Types.Metadata_j.string_of_t metadata) >>= fun _ ->
  Store.write t.store ~path:[uuid_s; "status"]
      (Types.Status_j.string_of_t Types.Status_t.Created) >>= fun _ ->
  Lwt_unix.truncate file Types.Metadata_j.(metadata.size) >>= fun _ ->
  {
    t = t;
    id = uuid;
    raw_file = file;
    metadata = metadata;
    status = Types.Status_t.Created;
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
  Store.write video.t.store ~path:[uuid_s; "status"]
      (Types.Status_j.string_of_t Types.Status_t.Finalized) >>= fun _ ->
  video.status <- Types.Status_t.Finalized;
  Hls_transcoder.schedule video.t.transcoder file dir video.t.encoding_options
      (function
      | Ok log ->
        Store.write video.t.store ~path:[uuid_s; "status"]
            (Types.Status_j.string_of_t Types.Status_t.Transcoded) >>= fun _ ->
        video.status <- Types.Status_t.Transcoded;
        return_unit
      | Error (log, status) ->
        let e = Types.Status_t.Transcoding_failed (log, status) in
        Store.write video.t.store ~path:[uuid_s; "status"]
            (Types.Status_j.string_of_t e) >>= fun _ ->
        video.status <- e;
        return_unit)
