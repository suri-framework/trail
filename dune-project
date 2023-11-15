(lang dune 3.10)

(name trail)

(generate_opam_files true)

(source
 (github leostera/trail))

(authors "Leandro Ostera <leandro@abstractmachines.dev>")

(maintainers "Leandro Ostera <leandro@abstractmachines.dev>")

(license MIT)

(package
 (name trail)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends
   (ocaml (>= "5.0.0"))
   riot
   nomad
   caravan
   (uuidm (>= "0.9.8"))
   dune)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
