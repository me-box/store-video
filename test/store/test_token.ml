open OUnit2

module Test (Token : Token.S) = struct

  let test ctx =
    let open Token in
    let key = ["test"] in
    let t = generate key @@ Date.advance_by_years (Date.now ()) 1 in
    
    let valid = match t |> to_string |> of_string with
      | Ok t -> is_valid key t
      | Error _ -> false
    in
    assert_bool "Invalid Token" valid

end

let test_nocrypto ctx =
  let module T = Test (Token.Nocrypto_token(ODate.Unix)) in
  T.test ctx

let () =
  run_test_tt_main ("nocrypto" >:: test_nocrypto)
