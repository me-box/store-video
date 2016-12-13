module type S = sig

  module Date : ODate.S

  type t

  val to_string : t -> string

  val of_string : string -> (t, unit) result

  val is_valid : Datastore_types_t.key -> t -> bool

  val generate : Datastore_types_t.key -> Date.t -> t

end

module Nocrypto_token (Date : ODate.S) : S
