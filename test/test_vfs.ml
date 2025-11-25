(* test/test_vfs.ml *)

let test_sandboxing () =
  let vfs = Poly.Poly_vfs.empty in
  match Poly.Poly_vfs.write_file vfs "../test.txt" "content" with
  | Ok _ -> print_endline "FAILURE: Sandboxing failed (allowed escape)"
  | Error _ -> print_endline "SUCCESS: Sandboxing prevented escape"

let () =
  test_sandboxing ()
