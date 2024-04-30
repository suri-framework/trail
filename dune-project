(lang dune 3.11)
(using mdx 0.4)
(using melange 0.1)

(name trail)

(generate_opam_files true)

(source
 (github suri-framework/trail))

(authors "Leandro Ostera <leandro@abstractmachines.dev>")

(maintainers "Leandro Ostera <leandro@abstractmachines.dev>")

(license MIT)

(package
 (name trail)
 (synopsis "A minimalistic, composable web framework for building HTTP/WebSocket servers")
 (description "Trail is a minimalistic, composable framework for building HTTP/WebSocket servers for Riot, inspired by Elixir's Plug & WebSock. It provides you with a small set of abstractions for building _trails_ that can be assembled to handle a request. This includes a logger, a router, a socket endpoint, an interface to handling web socket frames, and more")
 (depends
  (alcotest (and :with-test (>= "1.7.0")))
  (atacama (>= "0.0.1"))
  (bytestring (>= "0.0.1"))
  (http (>= "6.0.0~beta2"))
  (magic-mime (>= "1.3.1"))
  (mdx (and :with-test (>= "2.3.1")))
  (ocaml (>= "5.1.0"))
  (ppx_bitstring (>= "4.1.0"))
  (qcheck (and :with-test (>= "0.21.3")))
  (riot (>= "0.0.1"))
  (uuidm (>= "0.9.8"))
  dune)
 (tags
  (composable "web framework" http websockets ws riot multicore)))

(package
 (name sidewinder)
 (synopsis "")
 (description "")
 (depends
  (mdx (and :with-test (>= "2.3.1")))
  (ocaml (>= "5.1.0"))
  (magic-mime (>= "1.3.1"))
  (riot (>= "0.0.1"))
  (trail (>= "0.0.1"))
  (crunch (>= "3.3.1"))
  (serde_derive (>= "0.0.1"))
  melange
  dune)
 (sites (share static))
 (tags
  (composable "web framework" http websockets ws riot multicore)))
