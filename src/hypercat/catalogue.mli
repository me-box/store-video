module type S = sig

  type t

  val init : unit -> t Lwt.t

  val init_with : Types_t.catalogue -> t Lwt.t

  val catalogue : t -> Types_t.catalogue Lwt.t

  val add_item : t -> Types_t.item -> t Lwt.t

end
