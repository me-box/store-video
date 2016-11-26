module CF = Config_file

type key = string list

type storage = string

type value =
  | Int of int
  | Float of float
  | String of string
  | Bool of bool
  | Uri of Uri.t
  | Null

type access = {
  getter : unit -> value;
  setter : value -> unit;  
}

type t = {
  group : CF.group;
  path : string;
  params : (key * access) list;
}
  
let init path =
  let g = new CF.group in
  g#read path;
  { 
    group = g;
    path = path;
    params = [];
  }
  
let get c k =
  try 
    let a = List.assoc k c.params in
    a.getter ()
  with _ -> Null

let set c k v = 
  let r = match v with
    | Null ->  
      {
        c with params = List.remove_assoc k c.params
      }
    | v ->
      try 
        let a = List.assoc k c.params in
        a.setter v;
        c
      with e -> 
        let cp = new CF.string_cp ~group:c.group k "" "" in
        let getter = fun () -> match v with
          | Int _ -> Int(cp#get |> int_of_string)
          | Float _ -> Float(cp#get |> float_of_string)
          | String _ -> String(cp#get)
          | Bool _ -> Bool(cp#get |> bool_of_string)
          | Uri _ -> Uri(cp#get |> Uri.of_string)
          | Null -> Null
        in
        let a = {
          getter = getter;
          setter = (function
            | Int i -> string_of_int i |> cp#set
            | Float f -> string_of_float f |> cp#set
            | String s -> cp#set s
            | Bool b -> string_of_bool b |> cp#set
            | Uri u -> Uri.to_string u |> cp#set
            | Null -> ())
        } in
        a.setter v;
        { c with params = (k, a) :: c.params }
  in
  r.group#write r.path;
  r  
