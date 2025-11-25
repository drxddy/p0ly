(* lib/poly_ai.ml *)

module Prompt = struct
  type t = {
    system : string;
    user : string;
  }

  let create ~system ~user = { system; user }

  let to_string p =
    Printf.sprintf "System: %s\nUser: %s" p.system p.user
end

module Client = struct
  (* Mock implementation for now *)
  let chat prompt =
    let prompt_str = Prompt.to_string prompt in
    Logs.info (fun m -> m "Sending prompt to AI:\n%s" prompt_str);
    (* Simulate network delay *)
    (* Eio_unix.sleep 0.5; *)
    Ok "This is a mock response from the AI."
end
