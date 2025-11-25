(* lib/poly_ai.ml *)

module Prompt = struct
  type t = {
    system : string;
    user : string;
  }

  let create ~system ~user =
    let tools_desc = "
RESPONSE FORMAT:
You must reply with valid JSON only.
{
  \"tool\": \"write\" | \"read\" | \"index\",
  \"path\": \"<string>\",
  \"content\": \"<string, optional>\"
}
" in
    { system = system ^ tools_desc; user }

  let to_string p =
    Printf.sprintf "System: %s\nUser: %s" p.system p.user
end

module Client = struct
  let api_key = Sys.getenv_opt "GEMINI_API_KEY"

  let chat env prompt =
    match api_key with
    | None -> Error "GEMINI_API_KEY environment variable not set."
    | Some key ->
        let uri = Uri.of_string ("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=" ^ key) in
        let body_json =
          `Assoc [
            ("contents", `List [
              `Assoc [
                ("parts", `List [
                  `Assoc [("text", `String (Prompt.to_string prompt))]
                ])
              ]
            ])
          ]
          |> Yojson.Safe.to_string
        in
        try
          let mgr = Eio.Stdenv.process_mgr env in
          let args = ["curl"; "-s"; "-X"; "POST"; "-H"; "Content-Type: application/json"; "-d"; body_json; Uri.to_string uri] in
          let response_body = Eio.Process.parse_out mgr Eio.Buf_read.take_all ~stdin:(Eio.Flow.string_source "") args in
          let json = Yojson.Safe.from_string response_body in
          match json with
          | `Assoc fields ->
              begin match List.assoc_opt "candidates" fields with
              | Some (`List ((`Assoc candidate_fields) :: _)) ->
                  begin match List.assoc_opt "content" candidate_fields with
                  | Some (`Assoc content_fields) ->
                      begin match List.assoc_opt "parts" content_fields with
                      | Some (`List ((`Assoc part_fields) :: _)) ->
                          begin match List.assoc_opt "text" part_fields with
                          | Some (`String text) -> Ok text
                          | _ -> Error "Could not find text in response"
                          end
                      | _ -> Error "Could not find parts in content"
                      end
                  | _ -> Error "Could not find content in candidate"
                  end
              | _ -> Error "Could not find candidates in response"
              end
          | _ -> Error ("Invalid JSON response: " ^ response_body)
        with
        | exn -> Error ("System error: " ^ Printexc.to_string exn)
end
