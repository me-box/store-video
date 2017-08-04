type audio_bitrate =
  | ABR_64kbps
  | ABR_96kbps

let audio_bitrate_to_string = function
  | ABR_64kbps -> "64k"
  | ABR_96kbps -> "96k"

type quality_level =
  | QL_1_3
  | QL_2_1
  | QL_3_1
  | QL_3_2

let quality_level_to_sting = function
  | QL_1_3 -> "1.3"
  | QL_2_1 -> "2.1"
  | QL_3_1 -> "3.1"
  | QL_3_2 -> "3.2"

type max_bitrate =
  | MBR_192kbps
  | MBR_500kbps
  | MBR_1mbps
  | MBR_2mbps

let max_bitrate_to_string_short = function
  | MBR_192kbps -> "192K"
  | MBR_500kbps -> "500K"
  | MBR_1mbps -> "1M"
  | MBR_2mbps -> "2M"

let max_bitrate_to_string_long = function
  | MBR_192kbps -> "192000"
  | MBR_500kbps -> "500000"
  | MBR_1mbps -> "1000000"
  | MBR_2mbps -> "2000000"

type buffer_size =
  | BS_1M
  | BS_2M
  | BS_3M
  | BS_6M

let buffer_size_to_string = function
  | BS_1M -> "1M"
  | BS_2M -> "2M"
  | BS_3M -> "3M"
  | BS_6M -> "6M"

type frame_rate =
  | FR_10
  | FR_24

let frame_rate_to_string = function
  | FR_10 -> "10"
  | FR_24 -> "24"

type gop_length =
  | GL_30
  | GL_72

let gop_length_to_string = function
  | GL_30 -> "30"
  | GL_72 -> "72"

type frame_size =
  | FS_380x180
  | FS_420x270
  | FS_640x360
  | FS_1280x720

let frame_size_to_string = function
  | FS_380x180 -> "320x180"
  | FS_420x270 -> "420x270"
  | FS_640x360 -> "640x360"
  | FS_1280x720 -> "1280x720"

type encoding_options =
  audio_bitrate
  * quality_level
  * max_bitrate
  * buffer_size
  * frame_rate
  * gop_length
  * frame_size

type input_file = string

type output_dir = string

type execution_log = string

type error = execution_log * Unix.process_status

type callback = (execution_log, error) result -> unit Lwt.t

type t = {
  queue : (input_file * output_dir * encoding_options list * callback) Queue.t;
  condition : unit Lwt_condition.t;
  mutex : Lwt_mutex.t;
}

let create_index options out_dir =
  let f = Filename.concat out_dir "index.m3u8" in
  let open Lwt_io in
  let open Lwt in
  open_file
      ~flags:[O_WRONLY; O_CREAT; O_TRUNC]
      ~perm:0o640 ~mode:Output f >>= fun oc ->
  fprintl oc "#EXTM3U" >>= fun _ ->
  Lwt_list.iter_s (
      fun option ->
      let (bitrate, size) = match option with
      | (_, _, bitrate, _, _, _, size) ->
          (max_bitrate_to_string_long bitrate, frame_size_to_string size)
      in
      fprintlf oc "#EXT-X-STREAM-INF:BANDWIDTH=%s,RESOLUTION=%s"
          bitrate size >>= fun _ ->
      fprintlf oc "%s.m3u8" size
  ) options >>= fun _ ->
  Lwt_io.close oc

let make_args
    in_file
    (audio_bitrate,
    quality_level,
    max_bitrate,
    buffer_size,
    frame_rate,
    gop_length,
    frame_size)
    out_file =
  let audio_bitrate_s = audio_bitrate_to_string audio_bitrate in
  let quality_level_s = quality_level_to_sting quality_level in
  let max_bitrate_s = max_bitrate_to_string_short max_bitrate in
  let buffer_size_s = buffer_size_to_string buffer_size in
  let frame_rate_s = frame_rate_to_string frame_rate in
  let gop_length_s = gop_length_to_string gop_length in
  let frame_size_s = frame_size_to_string frame_size in
  [|
     "-y"; "-i"; in_file; "-c:a"; "aac";
      "-strict"; "experimental"; "-ac"; "2"; "-b:a"; audio_bitrate_s;
      "-ar"; "44100"; "-c:v"; "libx264"; "-pix_fmt"; "yuv420p";
      "-profile:v"; "baseline"; "-level"; quality_level_s;
      "-maxrate"; max_bitrate_s; "-bufsize"; buffer_size_s; "-crf";
      "18"; "-r"; frame_rate_s; "-g"; gop_length_s; "-f"; "hls";
      "-hls_time"; "9"; "-hls_list_size"; "0"; "-s"; frame_size_s; out_file;
  |]

let ffmpeg tmp_fd in_f out_dir options =
  let open Lwt in
  let out_f = match options with
      | (_, _, _, _, _, _, size) ->
          frame_size_to_string size
          |> Printf.sprintf "%s.m3u8"
          |> Filename.concat out_dir
  in
  Logs.debug (fun m -> m "Transcoder: processing \"%s\"" in_f);
  let args = make_args in_f options out_f in
  Lwt_process.exec ~stdout:(`FD_copy(tmp_fd))
      ~stderr:(`FD_copy(tmp_fd)) ("ffmpeg", args) >>= fun status ->
  Logs.debug (fun m -> m "Transcoder: processed \"%s\"" in_f);
  Lwt.return status

let create () =
  let open Lwt in
  let t = {
    queue = Queue.create ();
    condition = Lwt_condition.create ();
    mutex = Lwt_mutex.create ();
  } in
  let rec loop () =
    (match Queue.is_empty t.queue with
    | true ->
      Logs.debug (fun m -> m "HLS Transcoder: waiting for jobs");
      Lwt_condition.wait ~mutex:t.mutex t.condition
    | false ->
      Logs.debug (fun m -> m "HLS Transcoder: processing new jobs");
      let (in_f, out_dir, options, cb) = Queue.take t.queue in
      Lwt_mutex.unlock t.mutex;
      create_index options out_dir >>= fun _ ->
      let tmp_f = Filename.temp_file "hlst" ".buf" in
      let tmp_fd =
          Unix.openfile tmp_f Unix.([O_RDWR; O_CREAT; O_TRUNC]) 0o640
      in
      let rec encode_while = function
        | hd::tl ->
            ffmpeg tmp_fd in_f out_dir hd >>= (function
            | Lwt_unix.WEXITED(0) -> encode_while tl
            | err -> Error (err) |> return)
        | [] -> Ok () |> return
      in
      encode_while options >>= fun r ->
      Unix.lseek tmp_fd 0 Lwt_unix.SEEK_SET |> ignore;
      let buf = Buffer.create 16 in
      Lwt_io.of_unix_fd ~mode:Lwt_io.Input tmp_fd
      |> Lwt_io.read_lines
      |> Lwt_stream.iter (Buffer.add_string buf) >>= fun _ ->
      Unix.close tmp_fd;
      Unix.unlink tmp_f;
      let contents = Buffer.contents buf in
      let r = match r with
          | Ok () -> Ok (contents)
          | Error s -> Error (contents, s)
      in
      async (fun () -> cb r);
      Buffer.clear buf;
      Lwt_mutex.lock t.mutex) >>= fun _ ->
  loop ()
  in
  Lwt_mutex.lock t.mutex >>= fun _ ->
  Lwt.async loop;
  return t

let schedule t in_f out_dir options cb =
  Logs.debug (fun m -> m "HLS Transcoder: pushing job");
  Lwt_mutex.with_lock t.mutex (fun () ->
  Queue.add (in_f, out_dir, options, cb) t.queue;
  Lwt_condition.signal t.condition ();
  Lwt.return_unit)
