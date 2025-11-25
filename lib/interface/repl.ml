(* lib/interface/repl.ml *)

open Notty
open Notty_unix

type message_type =
  | User
  | AI
  | System
  | Tool

type message = {
  typ : message_type;
  content : string;
}

type t = {
  history : message list;
  input_buffer : string;
  vfs : Poly_vfs.t;
  env : Eio_unix.Stdenv.base;
}

let create env = {
  history = [{ typ = System; content = "Welcome to Poly! Type your goal." }];
  input_buffer = "";
  vfs = Poly_vfs.empty;
  env;
}

let render_message msg =
  let attr = match msg.typ with
    | User -> A.(fg cyan)
    | AI -> A.(fg green)
    | System -> A.(fg lightblack)
    | Tool -> A.(fg yellow)
  in
  let prefix = match msg.typ with
    | User -> "> "
    | AI -> "Poly: "
    | System -> "[System] "
    | Tool -> "[Tool] "
  in
  let lines = String.split_on_char '\n' (prefix ^ msg.content) in
  I.vcat (List.map (I.string attr) lines)

let render t =
  let messages = List.map render_message (List.rev t.history) in
  let input = I.string A.(fg white) ("> " ^ t.input_buffer) in
  let cursor = I.string A.(bg lightwhite) " " in
  let ui = I.vcat (messages @ [I.hcat [input; cursor]]) in
  ui

let run_brain_loop t goal =
  let initial_state = Poly_brain.Thinking (goal, t.vfs) in
  let rec loop state history =
    match state with
    | Poly_brain.Done result ->
        ({ t with history = { typ = AI; content = result } :: history }, state)
    | Poly_brain.Failed err ->
        ({ t with history = { typ = System; content = "Error: " ^ err } :: history }, state)
    | _ ->
        let next_state = Poly_brain.step t.env state in
        let new_history = match next_state with
          | Poly_brain.Acting (plan, _) -> { typ = AI; content = "Plan: " ^ plan } :: history
          | Poly_brain.Done res -> { typ = AI; content = res } :: history
          | Poly_brain.Failed err -> { typ = System; content = "Error: " ^ err } :: history
          | _ -> history
        in
        (* Update VFS from state if needed, here we assume VFS is threaded in state *)
        (* For simplicity in this step, we just recurse. In a real TUI we'd render intermediate steps. *)
        (* To make it truly interactive, we should probably return the intermediate state to the main loop *)
        loop next_state new_history
  in
  let (new_t, final_state) = loop initial_state t.history in
  (* Extract VFS from final state to persist it *)
  let final_vfs = match final_state with
    | Poly_brain.Thinking (_, v) | Poly_brain.Acting (_, v) | Poly_brain.Verifying (_, v) -> v
    | _ -> t.vfs (* Should extract from Done/Failed if possible, or threading needs improvement *)
  in
  { new_t with vfs = final_vfs }

let run env =
  let term = Term.create () in
  let rec loop t =
    Term.image term (render t);
    match Term.event term with
    | `Key (`Enter, _) ->
        let goal = String.trim t.input_buffer in
        if goal = "exit" || goal = "quit" then Term.release term
        else
          let t_with_input = { t with history = { typ = User; content = goal } :: t.history; input_buffer = "" } in
          Term.image term (render t_with_input); (* Render user input immediately *)
          
          (* Run the brain loop *)
          (* Note: This blocks the UI. Ideally we'd run this async. *)
          let t_after_brain = run_brain_loop t_with_input goal in
          loop t_after_brain
        
    | `Key (`ASCII 'c', [`Ctrl]) -> Term.release term; exit 0
    | `Key (`ASCII c, _) ->
        loop { t with input_buffer = t.input_buffer ^ String.make 1 c }
    | `Key (`Backspace, _) ->
        let len = String.length t.input_buffer in
        if len > 0 then
          loop { t with input_buffer = String.sub t.input_buffer 0 (len - 1) }
        else loop t
    | _ -> loop t
  in
  loop (create env)
