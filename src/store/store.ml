let () =
  Logs.set_level (Some Logs.Debug);
  Logs.set_reporter (Logs.format_reporter ());
  Logs.info (fun m -> m "Starting");
  Lwt_unix.on_signal Sys.sigint (fun signum -> exit 0) |> ignore

open Databox

module App : Application.S = struct
  
  let name = "databox-store-hls-video"
  
  let dir_store = "/store"
  let dir_uploaded = "/uploaded"
  let dir_hls = "/hls"
  
  open Irmin_unix
  
  module Config = Config_file
  
  module Store = Irmin_git.FS 
      (Irmin.Contents.String)
      (Irmin.Ref.String)
      (Irmin.Hash.SHA1) 
  
  let config = Config_file.init "config.txt"
  
  let store_config = Irmin_git.config ~root:dir_store ~bare:true ()
  
  let server_mode = `TCP (`Port 8080)
  
  let () =
    [ dir_store; dir_uploaded; dir_hls ] |> List.iter (
      fun dir ->
        match Sys.file_exists dir with
        | false -> Unix.mkdir dir 0o750
        | true -> (match Sys.is_directory dir with
          | true -> ()
          | false -> Sys.remove dir; Unix.mkdir dir 0o750))
  
end

let () =
  let open Lwt in
  let module Transcoder = Transcoder.Make(App) in
  let module Server = Http_server.Make(App)(Transcoder) in 
  Server.server |> Lwt_main.run
