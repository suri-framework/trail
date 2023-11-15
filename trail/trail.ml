module Conn = Connection
include Pipeline

module type Intf = sig
  type args

  val init : args -> args
  val run : Conn.t -> args -> Conn.t
end

let trail (type args) (module T : Intf with type args = args) (args : args) =
  let args = T.init args in
  fun conn _ctx -> T.run conn args

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

let logger args = trail (module Logger) args

module Request_id = Request_id

let request_id args = trail (module Request_id) args
