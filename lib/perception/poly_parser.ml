let parse_file path =
  print_endline ("Parsing " ^ path);
  try
    let ic = open_in path in
    let lexbuf = Lexing.from_channel ic in
    Location.init lexbuf path;
    let _ast = Parse.implementation lexbuf in
    close_in ic;
    print_endline "Parsed successfully!";
    (* We could convert 'ast' to Poly_ast here, but for now just printing success *)
    Ok (Poly_ast.Module { name = path; children = [] }) (* Returning dummy for now *)
  with
  | Sys_error msg -> Error msg
  | exn -> Error (Printexc.to_string exn)

