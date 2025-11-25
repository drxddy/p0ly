open Parsetree
open Asttypes
open Longident

let ast_of_structure_item (item : structure_item) : Poly_ast.t option =
  match item.pstr_desc with
  | Pstr_value (_, bindings) ->
      let bindings_ast =
        List.map (fun (vb : value_binding) ->
          match vb.pvb_pat.ppat_desc with
          | Ppat_var { txt = name; _ } ->
              Some (Poly_ast.Let { name; value = Poly_ast.Unknown "value" })
          | _ -> None
        ) bindings
        |> List.filter_map (fun x -> x)
      in
      if bindings_ast = [] then None else Some (Poly_ast.Block bindings_ast)
  | Pstr_eval (expr, _) ->
      begin match expr.pexp_desc with
      | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident name; _ }; _ }, args) ->
          let args_ast = List.map (fun (_, arg) ->
            match arg.pexp_desc with
            | Pexp_constant _ -> Poly_ast.Literal "constant"
            | _ -> Poly_ast.Unknown "arg"
          ) args in
          Some (Poly_ast.Call { func = name; args = args_ast })
      | _ -> Some (Poly_ast.Unknown "eval")
      end
  | _ -> None

let ast_of_structure (str : structure) : Poly_ast.t list =
  List.filter_map ast_of_structure_item str

let parse_file path =
  print_endline ("Parsing " ^ path);
  try
    let ic = open_in path in
    let lexbuf = Lexing.from_channel ic in
    Location.init lexbuf path;
    let ast = Parse.implementation lexbuf in
    close_in ic;
    print_endline "Parsed successfully!";
    let children = ast_of_structure ast in
    Ok (Poly_ast.Module { name = path; children })
  with
  | Sys_error msg -> Error msg
  | exn -> Error (Printexc.to_string exn)

