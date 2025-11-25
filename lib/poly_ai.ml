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
          Eio.Switch.run @@ fun sw ->
          let client =
            let authenticator = match Ca_certs.authenticator () with
              | Ok a -> a
              | Error (`Msg m) -> failwith ("Failed to load CA certs: " ^ m)
            in
            let https = Some (fun uri raw ->
              let host_str = Uri.host uri |> Option.value ~default:"localhost" in
              let host = Domain_name.of_string_exn host_str |> Domain_name.host_exn in
              match Tls.Config.client ~authenticator () with
              | Ok config -> Tls_eio.client_of_flow config ~host raw
              | Error (`Msg m) -> failwith ("TLS Config error: " ^ m)
            ) in
            Cohttp_eio.Client.make ~https (Eio.Stdenv.net env)
          in
          let body = Cohttp_eio.Body.of_string body_json in
          let resp, body = Cohttp_eio.Client.post ~sw ~body client uri in
          if Cohttp.Response.status resp |> Cohttp.Code.code_of_status |> fun c -> c >= 200 && c < 300 then
            let response_body = Eio.Buf_read.of_flow ~max_size:max_int body |> Eio.Buf_read.take_all in
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
          else
            let err_body = Eio.Buf_read.of_flow ~max_size:max_int body |> Eio.Buf_read.take_all in
            Error ("HTTP Error: " ^ (Cohttp.Response.status resp |> Cohttp.Code.string_of_status) ^ " Body: " ^ err_body)
        with
        | exn -> Error ("System error: " ^ Printexc.to_string exn)
end
