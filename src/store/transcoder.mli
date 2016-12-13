module type S = sig

  type job = string * (string -> (unit, string) result -> unit Lwt.t)

  val push : job -> unit Lwt.t

end

module Make (Application : Application.S) : S
