let () =
  let file = "test/test_poly.ml" in
  match Poly.Poly_parser.parse_file file with
  | Ok _ -> print_endline "Test passed: Parsed successfully"
  | Error msg -> print_endline ("Test failed: " ^ msg)
