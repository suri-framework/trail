module Adapter = Adapter
module Sock = Sock
module Frame = Frame
module Request = Request
module Response = Response
module Conn = Connection
include Pipeline

module type Intf = sig
  type args
  type state

  val init : args -> state
  val call : Conn.t -> state -> Conn.t
end

let use (type args) (module T : Intf with type args = args) (args : args) =
  let args = T.init args in
  fun conn -> T.call conn args

let handler adapter pipeline socket (req : Request.t) =
  let conn = Conn.make adapter socket req in
  let conn = Pipeline.run conn pipeline in

  if not (Conn.halted conn) then raise Conn.Connection_should_be_closed;

  match Conn.switch conn with Some switch -> `upgrade switch | None -> `close

module Router = Router
module Logger = Req_logger
module Request_id = Request_id
