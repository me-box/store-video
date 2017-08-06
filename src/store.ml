let () =
  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs.format_reporter ());
  Logs.info (fun m -> m "Starting");
  Lwt_unix.on_signal Sys.sigint (fun signum -> exit 0) |> ignore

let encoding_options = Hls_transcoder.([
  (ABR_64kbps, QL_1_3, MBR_192kbps, BS_1M, FR_10, GL_30, FS_380x180);
  (ABR_64kbps, QL_2_1, MBR_500kbps, BS_2M, FR_10, GL_30, FS_420x270);
  (ABR_96kbps, QL_3_1, MBR_1mbps, BS_3M, FR_24, GL_72, FS_640x360);
  (ABR_96kbps, QL_3_2, MBR_2mbps, BS_6M, FR_24, GL_72, FS_1280x720);
])

let () =
  let open Lwt in
  let raw_dir = "output/raw" in
  let transcoded_dir = "output/transcoded" in
  let metadata_dir = "output/metadata" in
  (Videostore.create ~raw_dir:raw_dir ~transcoded_dir:transcoded_dir
      ~metadata_dir:metadata_dir encoding_options >>= fun vstore ->
  Lwt_unix.openfile "test-data/test.mp4.js" [Unix.O_RDONLY] 0o644 >>= fun fd ->
  let ic = Lwt_io.of_fd ~mode:Lwt_io.Input fd in
  let stream = Lwt_io.read_lines ic in
  Lwt_stream.fold (fun line buf ->
          Buffer.add_string buf line; Buffer.add_char buf '\n'; buf)
      stream (Buffer.create 16) >>= fun buf ->
  let metadata = Buffer.contents buf |> Types.Metadata_j.t_of_string in
  Lwt_io.close ic >>= fun _ ->
  Videostore.init_video vstore metadata >>= fun v ->
  Lwt_unix.openfile "test-data/test.mp4" [Lwt_unix.O_RDONLY] 0o644 >>= fun fd ->
  let data =
        Lwt_bytes.map_file ~fd:(Lwt_unix.unix_file_descr fd) ~shared:false ()
  in
  Videostore.put_data v data 0 >>= fun _ ->
  Lwt_unix.close fd >>= fun _ ->
  Videostore.finalize v >>=
  fun _ -> (Lwt.wait () |> fst)) |> Lwt_main.run
