module type S = sig

  val name : string
  
  val dir_store : string
  val dir_uploaded : string
  val dir_hls : string
    
  module Config : Databox.Config.S
  
  module Store : Irmin.S 
      with type key = string list 
      and type value = string
  
  val config : Config.t
  
  val store_config : Irmin.config
  
  val server_mode : Conduit_lwt_unix.server
  
end