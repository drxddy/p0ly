(lang dune 3.11)

(name poly)

(version 0.1.0)

(package
 (name poly)
 (synopsis "A high-performance, structure-aware CLI coding agent")
 (description
  "Poly is a CLI coding agent built in OCaml that treats code as data (ASTs) rather than just text strings.")
 (depends
  (ocaml
   (>= 5.0.0))
  (dune
   (>= 3.11))
  (cmdliner
   (>= 1.2.0))
  (ppx_deriving_yojson
   (>= 3.7.0))
  (ppx_deriving
   (>= 5.2.1))
  (eio_main
   (>= 0.12))
  (cohttp-eio
   (>= 5.3.0))
  (yojson
   (>= 2.1.0))
  (logs
   (>= 0.7.0))
  (fmt
   (>= 0.9.0))
  (compiler-libs.common
   (>= 5.0.0))))
