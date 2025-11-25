(* lib/execution/poly_vfs.ml *)

module StringMap = Map.Make(String)

type t = {
  files : string StringMap.t;
}

let pp ppf vfs =
  Fmt.pf ppf "{ files = [ %a ] }"
    (Fmt.list ~sep:Fmt.comma (fun ppf (k, _) -> Fmt.string ppf k))
    (StringMap.bindings vfs.files)

let show vfs = Format.asprintf "%a" pp vfs

let empty = { files = StringMap.empty }

(* Sandboxing: Ensure path is relative and doesn't escape root *)
let sandbox_path path =
  if Filename.is_relative path && not (String.contains path ' ') && not (String.starts_with ~prefix:".." path) then
    Ok path
  else
    Error ("Invalid path (must be relative and safe): " ^ path)

let read_file vfs filename =
  match sandbox_path filename with
  | Error e -> Error e
  | Ok safe_path ->
      match StringMap.find_opt safe_path vfs.files with
      | Some content -> Ok content
      | None ->
          try
            let ic = open_in safe_path in
            let n = in_channel_length ic in
            let s = really_input_string ic n in
            close_in ic;
            Ok s
          with Sys_error msg -> Error msg

let write_file vfs filename content =
  match sandbox_path filename with
  | Error e -> Error e
  | Ok safe_path ->
      Ok { files = StringMap.add safe_path content vfs.files }

let delete_file vfs filename =
  match sandbox_path filename with
  | Error e -> Error e
  | Ok safe_path ->
      Ok { files = StringMap.remove safe_path vfs.files }

let list_dir _vfs dir =
  match sandbox_path dir with
  | Error e -> Error e
  | Ok safe_path ->
      try
        let files = Sys.readdir safe_path |> Array.to_list in
        Ok files
      with Sys_error msg -> Error msg

let mkdir _vfs dir =
  match sandbox_path dir with
  | Error e -> Error e
  | Ok safe_path ->
      try
        Sys.mkdir safe_path 0o755;
        Ok ()
      with Sys_error msg -> Error msg

let commit vfs =
  StringMap.iter (fun filename content ->
    let oc = open_out filename in
    output_string oc content;
    close_out oc
  ) vfs.files
