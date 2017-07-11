module type S = sig

  val server : unit Lwt.t

end

module Make
    (Application : Application.S)
    (Transcoder : Transcoder.S)
    (Token : Token.S) : S
