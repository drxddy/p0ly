(* lib/interface/cli.ml *)

open Cmdliner

let setup_log =
  let init style_renderer level =
    Fmt_tty.setup_std_outputs ?style_renderer ();
    Logs.set_level level;
    Logs.set_reporter (Logs_fmt.reporter ())
  in
  Term.(const init $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let parse_cmd =
  let doc = "Parse a file and print its AST" in
  let info = Cmd.info "parse" ~doc in
  let file = Arg.(required & pos 0 (some string) None & info [] ~docv:"FILE" ~doc:"The file to parse") in
  let run file =
    match Poly_parser.parse_file file with
    | Ok ast ->
        Poly_ast.to_yojson ast |> Yojson.Safe.pretty_to_string |> print_endline
    | Error e ->
        Logs.err (fun m -> m "Failed to parse file: %s" e)
  in
  Cmd.v info Term.(const run $ file)

let start_cmd =
  let doc = "Start the agent loop" in
  let info = Cmd.info "start" ~doc in
  let run () =
    Eio_main.run @@ fun env ->
    (Mirage_crypto_rng_eio.run [@alert "-deprecated"]) (module Mirage_crypto_rng.Fortuna) env @@ fun () ->
    Repl.run env
  in
  Cmd.v info Term.(const run $ const ())

let vfs_test_cmd =
  let doc = "Test VFS operations" in
  let info = Cmd.info "vfs-test" ~doc in
  let run () =
    let vfs = Poly_vfs.empty in
    match Poly_vfs.write_file vfs "test_vfs.txt" "Hello from VFS!" with
    | Ok vfs ->
        Poly_vfs.commit vfs;
        begin match Poly_vfs.read_file vfs "test_vfs.txt" with
        | Ok content -> print_endline ("Read back: " ^ content)
        | Error e -> print_endline ("Error reading: " ^ e)
        end
    | Error e -> print_endline ("Error writing: " ^ e)
  in
  Cmd.v info Term.(const run $ const ())

let ai_test_cmd =
  let doc = "Test AI integration" in
  let info = Cmd.info "ai-test" ~doc in
  let run () =
    Eio_main.run @@ fun env ->
    (Mirage_crypto_rng_eio.run [@alert "-deprecated"]) (module Mirage_crypto_rng.Fortuna) env @@ fun () ->
    let prompt = Poly_ai.Prompt.create ~system:"You are a helpful assistant." ~user:"Hello, AI!" in
    match Poly_ai.Client.chat env prompt with
    | Ok response -> print_endline ("AI Response: " ^ response)
    | Error e -> print_endline ("Error: " ^ e)
  in
  Cmd.v info Term.(const run $ const ())

let index_cmd =
  let doc = "Index a file and print its symbol table" in
  let info = Cmd.info "index" ~doc in
  let file = Arg.(required & pos 0 (some string) None & info [] ~docv:"FILE" ~doc:"The file to index") in
  let run file =
    match Poly_index.index_file file with
    | Ok table ->
        let symbols = Poly_index.SymbolTable.to_list table in
        Tui.render_symbol_table symbols
    | Error e ->
        Logs.err (fun m -> m "Failed to index file: %s" e)
  in
  Cmd.v info Term.(const run $ file)

let main_cmd =
  let doc = "A high-performance, structure-aware CLI coding agent" in
  let info = Cmd.info "poly" ~version:Poly_core.version ~doc in
  let default = Term.(const (fun () -> ()) $ setup_log) in
  Cmd.group info ~default [parse_cmd; start_cmd; vfs_test_cmd; ai_test_cmd; index_cmd]

let main () =
  exit (Cmd.eval main_cmd)
