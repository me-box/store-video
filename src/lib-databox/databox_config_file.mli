type storage = string
  
type t
  
val init : string -> t
  
include Databox_config.S with type t := t and type storage := storage
