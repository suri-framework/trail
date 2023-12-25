module Conn = Connection
include Pipeline

module type Intf = sig
  type args

  val init : args -> args
  val run : Conn.t -> args -> Conn.t
end

let trail (type args) (module T : Intf with type args = args) (args : args) =
  let args = T.init args in
  fun conn -> T.run conn args

let handler adapter pipeline socket req =
  let conn = Connection.make adapter socket req in
  let conn = Pipeline.run conn pipeline in
  if Conn.halted conn then () else raise Connection.Connection_should_be_closed

let start_link ~port ?(adapter = (module Nomad_adapter : Adapter.Intf)) pipeline
    =
  Atacama.start_link ~port
    (module Nomad.Atacama_handler)
    {
      parser = Nomad.Atacama_handler.http1 ();
      handler = handler adapter pipeline;
    }

module Logger = Logger

let logger args = trail (module Logger) args

module Request_id = Request_id

let request_id args = trail (module Request_id) args
