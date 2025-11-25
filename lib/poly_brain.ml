(* lib/poly_brain.ml *)

type state =
  | Thinking of string * Poly_vfs.t (* Goal, VFS *)
  | Acting of string * Poly_vfs.t (* Plan/Tool, VFS *)
  | Verifying of string * Poly_vfs.t (* Verification, VFS *)
  | Done of string
  | Failed of string
  [@@deriving show]

let parse_tool_from_llm response =
  (* Simple heuristic parsing for now *)
  if String.starts_with ~prefix:"WRITE:" response then
    let content = String.sub response 6 (String.length response - 6) |> String.trim in
    match String.split_on_char '|' content with
    | [path; data] -> Some (Poly_tools.Write (String.trim path, String.trim data))
    | _ -> None
  else if String.starts_with ~prefix:"READ:" response then
    let path = String.sub response 5 (String.length response - 5) |> String.trim in
    Some (Poly_tools.Read path)
  else if String.starts_with ~prefix:"INDEX:" response then
    let path = String.sub response 6 (String.length response - 6) |> String.trim in
    Some (Poly_tools.Index path)
  else
    None

let step env current_state =
  match current_state with
  | Thinking (goal, vfs) ->
      Logs.info (fun m -> m "Thinking about: %s" goal);
      let prompt = Poly_ai.Prompt.create
        ~system:"You are a coding agent. Use tools: WRITE:path|content, READ:path, INDEX:path. Reply ONLY with a tool command."
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
