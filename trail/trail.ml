module Conn = Connection
include Pipeline

let handler adapter pipeline ctx socket req =
  let conn = Connection.make adapter socket req in
  let ctx = { ctx } in
  let conn = Pipeline.run ctx conn pipeline in
  if conn.halted then () else raise Connection.Connection_should_be_closed

let start_link ~port ?(adapter = (module Nomad_adapter : Adapter.Intf)) pipeline
    ctx =
  Atacama.start_link ~port
    (module Nomad.Atacama_handler)
    { buffer = Bigstringaf.empty; handler = handler adapter pipeline ctx }

module Logger = Logger
module Request_id = Request_id
