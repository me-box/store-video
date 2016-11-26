module type S = sig
  
  val server : unit Lwt.t
  
end

module Make 
    (Application : Application.S)
    (Transcoder : Transcoder.S) : S = struct

  open Lwt
  module Re2 = Re2.Std.Re2
  module Body = Cohttp_lwt_body
  module Code = Cohttp.Code
  module Header = Cohttp.Header
  module Request = Cohttp_lwt_unix.Request
  module DSType = Datastore_types_t
  module DSType_conv = Datastore_types_j
  
  module Server = struct
    
    let add_headers = function
      | Some h -> Header.add h "Access-Control-Allow-Origin" "*"
      | None -> Header.init_with "Access-Control-Allow-Origin" "*" 
    
    let respond_string ?headers =
      Cohttp_lwt_unix.Server.respond_string ~headers:(add_headers headers)
      
    let respond_error ?headers = 
      Cohttp_lwt_unix.Server.respond_error ~headers:(add_headers headers)
      
    let respond_file ?headers = 
      Cohttp_lwt_unix.Server.respond_file ~headers:(add_headers headers)
      
    let respond ?headers = 
      Cohttp_lwt_unix.Server.respond ~headers:(add_headers headers)
       
  end
  
  module API_server = struct
  
    let uri_pattern = Re2.create_exn "^/api/.*$"
    
    let uri_pattern_upload = Re2.create_exn "^/api/v1/media/([^/]+)/upload/?$"
    
    let uri_pattern_media = Re2.create_exn "^/api/v1/media/([^/]+)/?$"
    
    let media_key_prefix = ["media"; "v1";] 
    
    let rec gen_uuid store =
      let open Lwt in
      let module Store = Application.Store in 
      let id = 
        Uuidm.v4_gen (Random.State.make_self_init ()) () |> Uuidm.to_string
      in
      let key = media_key_prefix @ [id] in
      Store.read (store "Reading") key >>= function
      | None -> return id
      | Some _ -> gen_uuid store
    
    let respond_media_list req body =
      let headers = (Header.init () |> Header.add_list) [
        ("Allow", "GET, POST, OPTIONS");
      ] in
      match Request.meth req with
      | `GET -> 
        let module Store = Application.Store in
        let module View = Irmin.View(Store) in
        let open Lwt in
        Store.Repo.create Application.store_config >>= 
        Store.master Irmin_unix.task >>= fun t ->
        View.of_path (t "Creating view for media/v1") 
            media_key_prefix >>= fun v -> 
        View.list v [] >>= fun v ->
        Lwt_list.map_p (fun s -> 
          let key = media_key_prefix @ s in
          Store.read_exn (t "Reading") key >>= fun media_s ->
          DSType_conv.media_of_string media_s |> return
        ) v >>= fun list ->
        let response = DSType_conv.string_of_medias list in
        Server.respond_string ~status:`OK ~body:response () 
        
      | `POST ->
        let req_headers = Request.headers req in
        (match Header.get req_headers "content-type" with
        
        | Some s when (String.lowercase_ascii s) = "application/json" ->
          (Body.to_string body >>= fun body ->
          (try        
            let m = DSType_conv.media_of_string body in
            let module Store = Application.Store in
            let open Lwt in 
            Store.Repo.create Application.store_config >>= 
            Store.master Irmin_unix.task >>= fun t ->
            gen_uuid t >>= fun id ->
            let file_path = (Application.dir_uploaded ^ "/" ^ id) in
            Lwt_unix.openfile file_path [Lwt_unix.O_CREAT] 0o640 >>= 
            Lwt_unix.close >>= fun _ ->
            Lwt_unix.truncate file_path DSType.(m.size) >>= fun _ ->
            let m = DSType.({ m with id = Some(id) }) in
            let m_str = DSType_conv.string_of_media m in
            Store.update (t ("Updating media/v1/" ^ id)) 
                (media_key_prefix @ [id]) m_str >>= fun _ ->
            let headers = 
              Header.add headers "Content-Type" "application/json" 
            in            
            Server.respond_string ~headers ~status:`OK ~body:m_str ()
          with _ ->
            Server.respond_error ~headers ~status:`Bad_request ~body:"" ()))
        
        | _ -> Server.respond_error ~headers 
            ~status:`Unsupported_media_type ~body:"" ())

      | `OPTIONS -> Server.respond ~headers ~status:`OK ~body:Body.empty ()
      | _ -> 
        Server.respond_error ~headers ~status:`Method_not_allowed ~body:"" ()
    
    let respond_media_item req id = 
      let headers = (Header.init () |> Header.add_list) [
        ("Allow", "GET, OPTIONS");
      ] in
      match Request.meth req with
      | `GET -> 
        (let module Store = Application.Store in
        let open Lwt in 
        Store.Repo.create Application.store_config >>= 
        Store.master Irmin_unix.task >>= fun t ->
        let key = media_key_prefix @ [id] in
        Store.read (t "Reading") key >>= function
        | None -> Server.respond_error ~status:`Not_found ~body:"" ()
        | Some m -> 
          let headers = Header.add headers "Content-Type" "application/json" in
          Server.respond_string ~headers ~status:`OK ~body:m ())
      | `OPTIONS -> Server.respond ~headers ~status:`OK ~body:Body.empty ()
      | _ -> 
        Server.respond_error ~headers ~status:`Method_not_allowed ~body:"" ()
        
    let respond_media_upload req body id =
      let headers = (Header.init () |> Header.add_list) [
        ("Allow", "PUT, OPTIONS");
      ] in
      match Request.meth req with
      | `PUT -> 
        (let uri = Request.uri req in
        let offset = match Uri.get_query_param uri "offset" with
          | Some s -> int_of_string s
          | None -> 0
        in
        let close = Uri.get_query_param uri "close" in
        let module Store = Application.Store in
        let open Lwt in 
        Store.Repo.create Application.store_config >>= 
        Store.master Irmin_unix.task >>= fun t ->
        let key = media_key_prefix @ [id] in
        Store.read (t "Reading") key >>= function
        | None -> Server.respond_error ~status:`Not_found ~body:"" ()
        | Some m -> 
          (let file_path = (Application.dir_uploaded ^ "/" ^ id) in
            Lwt_unix.openfile file_path [Lwt_unix.O_RDWR] 0o640 >>= fun fd ->
            let out = Lwt_io.of_fd ~mode:Lwt_io.Output fd in
            Lwt_io.set_position out (Int64.of_int offset) >>= fun _ ->
            Lwt_stream.iter_s (fun s -> Lwt_io.write out s) 
                (Body.to_stream body) >>= fun _ ->
            Lwt_io.close out >>= fun _ ->
            let job = (id, fun id result -> 
              Logs.debug (fun m -> m "Encoding complete");
              Lwt.return_unit)
            in
            Transcoder.push job >>= fun _ ->
            Server.respond ~headers ~status:`OK ~body:Body.empty ()))
      | `OPTIONS -> Server.respond ~headers ~status:`OK ~body:Body.empty ()
      | _ -> 
        Server.respond_error ~headers ~status:`Method_not_allowed ~body:"" ()
    
    let respond req body = function 
      | "/api/v1/media" | "/api/v1/media/" -> respond_media_list req body
      | p when Re2.matches uri_pattern_media p ->
        let matches = Re2.get_matches_exn uri_pattern_media p |> List.hd in
        let id = Re2.Match.get_exn ~sub:(`Index(1)) matches in
        respond_media_item req id
      | p when Re2.matches uri_pattern_upload p ->
        let matches = Re2.get_matches_exn uri_pattern_upload p |> List.hd in
        let id = Re2.Match.get_exn ~sub:(`Index(1)) matches in
        respond_media_upload req body id
      | _ -> Server.respond_error ~status:`Not_found ~body:"" ()
    
  end
  
  module HLS_server = struct
    
    let uri_pattern = Re2.create_exn "^/hls/.*$"
    
    let respond req path =
      let headers = Header.init_with "Allow" "GET, HEAD, OPTIONS" in
      Lwt_unix.file_exists path >>= function
      | false -> 
        Server.respond_error ~headers ~status:`Not_found ~body:"" ()
      | true -> 
        let content_type = match Filename.extension path 
              |> String.lowercase_ascii with
          | ".m3u8" -> "application/x-mpegURL"
          | ".ts" -> "video/MP2T"
          | _ -> "application/octet-stream"
        in
        (match Request.meth req with
        | `GET ->  
          let headers = Header.add headers "Content-Type" content_type in
          Server.respond_file ~headers ~fname:path ()
        | `OPTIONS -> Server.respond ~headers ~status:`OK ~body:Body.empty ()
        | `HEAD ->
          Lwt_unix.stat path >>= fun stat ->
          let headers = Header.add_list headers [
            ("Content-Type", content_type);
            ("content-length", string_of_int stat.Lwt_unix.st_size);
          ] in 
          Server.respond ~headers ~status:`OK ~body:Body.empty ()
        | _ -> Server.respond_error ~headers
            ~status:`Method_not_allowed ~body:"" ()) 

  end
  
  let server =
    let callback _conn req body =
      Logs.debug (fun m -> m "Received request: [%s] %s" 
          (Request.meth req |> Code.string_of_method)
          (Request.uri req |> Uri.to_string));
      match Request.uri req |> Uri.path with
      | p when Re2.matches API_server.uri_pattern p -> 
        API_server.respond req body p
      | p when Re2.matches HLS_server.uri_pattern p -> 
        HLS_server.respond req p
      | _ -> Server.respond_error ~status:`Not_found ~body:"" ()
    in
    let module Server = Cohttp_lwt_unix.Server in
    Server.create ~mode:Application.server_mode (Server.make ~callback ())

end
