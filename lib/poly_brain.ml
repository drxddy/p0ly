(* lib/poly_brain.ml *)

type state =
  | Thinking of string * Poly_vfs.t (* Goal, VFS *)
  | Acting of string * Poly_vfs.t (* Plan/Tool, VFS *)
  | Verifying of string * Poly_vfs.t (* Verification, VFS *)
  | Done of string
  | Failed of string
  [@@deriving show]

let parse_tool_from_llm response =
  try
    let json = Yojson.Safe.from_string response in
    let open Yojson.Safe.Util in
    let tool = member "tool" json |> to_string in
    let path = member "path" json |> to_string in
    match tool with
    | "write" ->
        let content = member "content" json |> to_string in
        Some (Poly_tools.Write (path, content))
    | "read" -> Some (Poly_tools.Read path)
    | "index" -> Some (Poly_tools.Index path)
    | _ -> None
  with _ -> None

let step env current_state =
  match current_state with
  | Thinking (goal, vfs) ->
      Logs.info (fun m -> m "Thinking about: %s" goal);
      let prompt = Poly_ai.Prompt.create
        ~system:"You are a coding agent. You must act autonomously to achieve the goal."
        ~user:("Goal: " ^ goal) in
      begin match Poly_ai.Client.chat env prompt with
      | Ok response ->
          Logs.info (fun m -> m "LLM Plan: %s" response);
          Acting (response, vfs)
      | Error e -> Failed ("LLM Error: " ^ e)
      end
  | Acting (plan, vfs) ->
      Logs.info (fun m -> m "Acting on: %s" plan);
      begin match parse_tool_from_llm plan with
      | Some tool ->
          begin match Poly_tools.execute tool vfs with
          | Ok (new_vfs, result) ->
              Logs.info (fun m -> m "Tool Result: %s" result);
              Poly_vfs.commit new_vfs; (* Auto-commit for now *)
              Done ("Executed: " ^ Poly_tools.to_string tool)
          | Error e -> Failed ("Tool Failed: " ^ e)
          end
      | None -> Failed ("Invalid tool command from LLM: " ^ plan)
      end
  | Verifying (check, _) ->
      Logs.info (fun m -> m "Verifying: %s" check);
      Done "Verified"
  | Done result -> Done result
  | Failed error -> Failed error

let rec loop env state =
  match state with
  | Done _ | Failed _ -> state
  | _ ->
      let next_state = step env state in
      loop env next_state
