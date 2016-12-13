module type S = sig

    type error

    type 'ok t = ('ok, error) result Lwt.t

    val bind : 'ok t -> ('ok -> 'b t) -> 'b t

    val ( >>= ) : 'ok t -> ('ok -> 'b t) -> 'b t

    val return : 'ok -> 'ok t

    val fail : error -> _ t

end
