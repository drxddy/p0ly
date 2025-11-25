(* lib/interface/tui.ml *)

open Notty
open Notty.Infix

let spinner_frames = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]

let render_spinner frame_idx text =
  let frame = spinner_frames.(frame_idx mod Array.length spinner_frames) in
  let image = I.string A.(fg lightblue) frame <|> I.string A.empty (" " ^ text) in
  Notty_unix.output_image image

let render_symbol_table symbols =
  let header = I.string A.(fg green ++ st bold) "SYMBOL TABLE" in
  let rows =
    List.map (fun (sym : Poly_index.Symbol.t) ->
      I.string A.(fg cyan) sym.name <|> I.string A.empty " : " <|> I.string A.(fg yellow) sym.kind
    ) symbols
  in
  let image = I.vcat (header :: rows) in
  Notty_unix.output_image image
