module type S = sig
  
  type job = string * (string -> (unit, string) result -> unit Lwt.t)
  
  val push : job -> unit Lwt.t

end

module Make (Application : Application.S) : S = struct
  
  type job = string * (string -> (unit, string) result -> unit Lwt.t)

  type t = {
    queue : job Queue.t;
    condition : unit Lwt_condition.t;
    mutex : Lwt_mutex.t;
  }
  
  let index_m3u8 = 
    "#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=192000,RESOLUTION=320x180
320x180.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=480x270
480x270.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360
640x360.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
1280x720.m3u8"

  let make_args a level maxrate bufsize r g s id = [|
      "-y"; "-i"; (Application.dir_uploaded ^ "/" ^ id); "-c:a"; "aac"; 
      "-strict"; "experimental"; "-ac"; "2"; "-b:a"; a; "-ar"; "44100"; 
      "-c:v"; "libx264"; "-pix_fmt"; "yuv420p"; "-profile:v"; "baseline"; 
      "-level"; level; "-maxrate"; maxrate; "-bufsize"; bufsize; "-crf";
      "18"; "-r"; r; "-g"; g; "-f"; "hls"; "-hls_time"; "9"; 
      "-hls_list_size"; "0"; "-s"; s; 
      (Application.dir_hls ^ "/" ^ id ^ "/" ^ s ^ ".m3u8"); 
    |]
  
  let args id = [
      make_args "64k" "1.3" "192K" "1M" "10" "30" "320x180" id;
      make_args "64k" "2.1" "500K" "2M" "10" "30" "420x270" id;
      make_args "96k" "3.1" "1M" "3M" "24" "72" "640x360" id;
      make_args "96k" "3.2" "2M" "6M" "24" "72" "1280x720" id;
    ]
  
  let ffmpeg job =
    let open Lwt in
    let id = fst job in
    let cb = snd job in
    Logs.debug (fun m -> m "Transcoder: processing \"%s\"" id);
    let dir = Application.dir_hls ^ "/" ^ id in
    Lwt_unix.file_exists dir >>= (function
    | true -> return_unit
    | false -> Lwt_unix.mkdir dir 0o750) >>= fun _ ->
    Lwt_unix.openfile (dir ^ "/" ^ "index.m3u8") 
        [Lwt_unix.O_WRONLY; Lwt_unix.O_CREAT] 0o640 >>= fun fd ->
    let chan = Lwt_io.of_fd ~mode:Lwt_io.Output fd in
    Lwt_io.write chan index_m3u8 >>= fun _ ->
    Lwt_io.close chan >>= fun _ ->
    Lwt_list.iter_s (fun args ->  
      Lwt_process.exec ~stdout:`Dev_null ~stderr:`Dev_null ("/ffmpeg", args) 
      >>= fun _ -> return_unit
    ) (args id) >>= fun _ ->
    cb id (Ok()) >>= fun _ ->
    Logs.debug (fun m -> m "Transcoder: processed \"%s\"" id);
    Lwt.return_unit
  
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
        Logs.debug (fun m -> m "Transcoder: waiting for jobs");
        Lwt_condition.wait ~mutex:t.mutex t.condition
      | false ->
        Logs.debug (fun m -> m "Transcoder: processing new jobs"); 
        let e = Queue.take t.queue in 
        Lwt_mutex.unlock t.mutex;
        ffmpeg e >>= fun _ ->
        Lwt_mutex.lock t.mutex) >>= fun _ ->
      loop ()
    in
    Lwt_mutex.lock t.mutex >>= fun _ ->
    Lwt.async loop;
    return t
    
  let t = create ()
    
  let push job =
    let open Lwt in
    t >>= fun t ->
    Logs.debug (fun m -> m "Transcoder: pushing job");
    Lwt_mutex.with_lock t.mutex (fun () -> 
    Queue.add job t.queue;
    Lwt_condition.signal t.condition ();
    Lwt.return_unit)

end
