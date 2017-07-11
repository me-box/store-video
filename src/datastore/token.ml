module type S = sig

  module Date : ODate.S

  type t

  val to_string : t -> string

  val of_string : string -> (t, unit) result

  val is_valid : Types_t.key -> t -> bool

  val generate : Types_t.key -> Date.t -> t

end

module Nocrypto_token (Date : ODate.S) = struct

  module Date = Date

  type t = Cstruct.t

  let () = ignore @@ Nocrypto_entropy_lwt.initialize ()
  let priv = Nocrypto.Rsa.generate 2048

  let to_string t = Nocrypto.Base64.encode t |> Cstruct.to_string

  let of_string s =
    match Cstruct.of_string s |> Nocrypto.Base64.decode with
    | Some cs -> Ok cs
    | None -> Error ()

  let generate key expiry =
    let expiry_s = Date.To.seconds expiry in
    let token = Types_j.string_of_token (key, expiry_s)
        |> Cstruct.of_string
    in
    let open Nocrypto.Rsa in
    encrypt ~key:(pub_of_priv priv) token

  let is_valid key t =
    let open Nocrypto.Rsa in
    let d = decrypt ~key:priv t |> Cstruct.to_string in
    let b = String.rindex d '\000' + 1 in
    let (key_actual, expiry) = String.sub d b (String.length d - b)
        |> Types_j.token_of_string
    in
    let keys_match =
      try
        List.for_all2 (fun a b -> a = b) key_actual key
      with Invalid_argument _ -> false
    in
    let in_date = Date.is_after (Date.From.seconds expiry) @@ Date.now () in
    keys_match && in_date

end
