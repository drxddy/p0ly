(* lib/poly_brain.ml *)

type state =
  | Thinking of string (* Input/Goal *)
  | Acting of string (* Plan/Action *)
  | Verifying of string (* Verification Step *)
  | Done of string (* Result *)
  | Failed of string (* Error *)
[@@deriving show]

let step current_state =
  match current_state with
  | Thinking goal ->
      Logs.info (fun m -> m "Thinking about: %s" goal);
      (* Mock transition: Thinking -> Acting *)
      Acting ("Plan for: " ^ goal)
  | Acting plan ->
      Logs.info (fun m -> m "Acting on: %s" plan);
      (* Mock transition: Acting -> Verifying *)
      Verifying ("Verify: " ^ plan)
  | Verifying check ->
      Logs.info (fun m -> m "Verifying: %s" check);
      (* Mock transition: Verifying -> Done *)
      Done "Success"
  | Done result ->
      Logs.info (fun m -> m "Done: %s" result);
      Done result (* Terminal state *)
  | Failed error ->
      Logs.err (fun m -> m "Failed: %s" error);
      Failed error (* Terminal state *)

let rec loop state =
  match state with
  | Done _ | Failed _ -> state
  | _ ->
      let next_state = step state in
      loop next_state
