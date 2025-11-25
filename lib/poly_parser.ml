(* lib/parser.ml *)

open Poly_ast

let parse_file filename =
  (* Mock implementation for now *)
  let mock_ast =
    Module {
      name = Filename.basename filename;
      children = [
        Function {
          name = "main";
          args = [];
          body = [
            Call {
              func = "print_endline";
              args = [Literal "\"Hello from PolyAST!\""]
            }
          ]
        }
      ]
    }
  in
  Ok mock_ast
