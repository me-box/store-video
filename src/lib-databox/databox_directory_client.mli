module type S = sig
  
  module Response : sig
   
    type error = [
      | `Unknown_error
      | `Not_implemented_error
    ] 
    
    include Databox_http_response.S with type error := error

  end
  
  open Databox_directory_types_t
  
  val register_vendor : vendor -> vendor Response.t
  
  val get_datastore : hostname:string -> datastore Response.t
  
  val register_driver : driver -> driver Response.t 
  
  val register_sensor_type : sensor_type -> sensor_type Response.t
  
  val register_sensor : sensor -> sensor Response.t
  
  val register_datastore : datastore -> datastore Response.t
  
end

val create : (module Cohttp_lwt.Client) -> Uri.t -> (module S)
