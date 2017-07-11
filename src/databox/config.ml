module type S = sig
  
  type key = string list
  
  type storage
  
  type value =
    | Int of int
    | Float of float
    | String of string
    | Bool of bool
    | Uri of Uri.t
    | Null
  
  type t
  
  val get : t -> key -> value
  
  val set : t -> key -> value -> t
    
end
