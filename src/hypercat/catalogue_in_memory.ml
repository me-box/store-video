type t = Types_t.catalogue

let init () = Types_t.({
    catalogue_metadata = [];
    items = [];
}) |> Lwt.return

let init_with c = Lwt.return c

let catalogue t = Lwt.return t

let add_item t item = 
    Types_t.({ t with items = item :: t.items})
    |> Lwt.return
