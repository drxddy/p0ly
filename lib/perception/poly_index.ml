(* lib/perception/poly_index.ml *)

module Symbol = struct
  type t = {
    name : string;
    kind : string;
    location : string;
  }
  [@@deriving show, yojson]
end

module SymbolTable = struct
  type t = (string, Symbol.t) Hashtbl.t

  let create () = Hashtbl.create 100

  let add table symbol =
    Hashtbl.replace table symbol.Symbol.name symbol

  let to_list table =
    Hashtbl.fold (fun _ v acc -> v :: acc) table []
end

let rec index_ast (table : SymbolTable.t) (ast : Poly_ast.t) =
  match ast with
  | Poly_ast.Module { children; _ } ->
      List.iter (index_ast table) children
  | Poly_ast.Function { name; _ } ->
      SymbolTable.add table { name; kind = "Function"; location = "unknown" }
  | Poly_ast.Let { name; _ } ->
      SymbolTable.add table { name; kind = "Variable"; location = "unknown" }
  | Poly_ast.Block children ->
      List.iter (index_ast table) children
  | _ -> ()

let index_file path =
  match Poly_parser.parse_file path with
  | Ok (Poly_ast.Module { children; _ }) ->
      let table = SymbolTable.create () in
      List.iter (index_ast table) children;
      Ok table
  | Ok _ -> Error "Expected a module"
  | Error e -> Error e
