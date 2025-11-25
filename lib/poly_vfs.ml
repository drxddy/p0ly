(* lib/poly_vfs.ml *)

module StringMap = Map.Make(String)

type t = {
  files : string StringMap.t;
}

let empty = { files = StringMap.empty }

let read_file vfs filename =
  match StringMap.find_opt filename vfs.files with
  | Some content -> Ok content
  | None ->
      try
        let ic = open_in filename in
        let n = in_channel_length ic in
        let s = really_input_string ic n in
        close_in ic;
        Ok s
      with Sys_error msg -> Error msg

let write_file vfs filename content =
  { files = StringMap.add filename content vfs.files }

let commit vfs =
  StringMap.iter (fun filename content ->
    let oc = open_out filename in
    output_string oc content;
    close_out oc
  ) vfs.files
