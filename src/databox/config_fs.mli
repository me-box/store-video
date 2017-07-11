type storage = string
  
type t
  
val init : string -> t
  
include Config.S with type t := t and type storage := storage
