(* lib/poly_ast.ml *)

type t =
  | Module of { name : string; children : t list }
  | Function of { name : string; args : string list; body : t list }
  | Call of { func : string; args : t list }
  | Let of { name : string; value : t }
  | Identifier of string
  | Literal of string
  | Block of t list
  | Unknown of string
[@@deriving show, yojson]
