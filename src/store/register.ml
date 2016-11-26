let datastore = Databox_directory_types_t.({
  id = None;
  hostname = Sys.getenv "DATABOX_LOCAL_NAME";
  api_url = ":" ^ (string_of_int listen_port) ^ "/api";
});;

let register () =
  Logs.info (fun m -> m "Registering with the Databox Directory");
  let directory_endpoint = Sys.getenv "DATABOX_DIRECTORY_ENDPOINT" in
  Logs.info (fun m -> 
      m "Using Databox Directory Endpoint: %s" directory_endpoint);
  
  let module Dir =
    (val Databox_directory_client.create
        (module Cohttp_lwt_unix.Client : Cohttp_lwt.Client)
        (Uri.of_string directory_endpoint) 
        : Databox_directory_client.S)
  in
  
  let open Dir.Response in
  let open Directory_types in
  
  let pp_id = function 
    | None -> "None"
    | Some id -> string_of_int id
  in 
  
  Logs.info (fun m -> m "Attempting to register datastore");
  Dir.register_datastore datastore 
  >>= fun datasore ->
  Logs.info (fun m -> 
      m "Registered datastore with ID: %s" (pp_id datastore.id));
  return datastore