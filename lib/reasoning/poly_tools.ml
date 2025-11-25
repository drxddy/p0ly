(* lib/reasoning/poly_tools.ml *)

type t =
  | Read of string
  | Write of string * string
  | ListDir of string
  | Index of string
  [@@deriving show, yojson]

let to_string = function
  | Read path -> Printf.sprintf "Read(%s)" path
  | Write (path, _) -> Printf.sprintf "Write(%s, <content>)" path
  | ListDir path -> Printf.sprintf "ListDir(%s)" path
  | Index path -> Printf.sprintf "Index(%s)" path

let execute tool vfs =
  match tool with
  | Read path ->
      begin match Poly_vfs.read_file vfs path with
      | Ok content -> Ok (vfs, "Read content: " ^ content)
      | Error e -> Error ("Failed to read: " ^ e)
      end
  | Write (path, content) ->
      begin match Poly_vfs.write_file vfs path content with
      | Ok new_vfs -> Ok (new_vfs, "Successfully wrote to " ^ path)
      | Error e -> Error ("Failed to write: " ^ e)
      end
  | ListDir path ->
      begin match Poly_vfs.list_dir vfs path with
      | Ok files -> Ok (vfs, "Files: " ^ String.concat ", " files)
      | Error e -> Error ("Failed to list dir: " ^ e)
      end
  | Index path ->
      begin match Poly_index.index_file path with
      | Ok table ->
          let symbols = Poly_index.SymbolTable.to_list table in
          let summary = List.map (fun s -> s.Poly_index.Symbol.name) symbols |> String.concat ", " in
          Ok (vfs, "Indexed symbols: " ^ summary)
      | Error e -> Error ("Failed to index: " ^ e)
      end
