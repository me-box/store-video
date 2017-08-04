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
  (Hls_transcoder.create () >>= fun t ->
  let cb = function
      | Ok log -> print_endline log; return_unit
      | Error (log, status) -> print_endline log; return_unit
  in
  Hls_transcoder.schedule
      t "test-data/test.mp4" "output" encoding_options cb >>=
  fun _ -> (Lwt.wait () |> fst)) |> Lwt_main.run
