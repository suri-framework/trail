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

let trail (type args) (module T : Intf with type args = args) (args : args) =
  let args = T.init args in
  fun conn -> T.call conn args

let handler pipeline socket (req : Request.t) =
  let conn = Conn.make socket req in
  let conn = Pipeline.run conn pipeline in

  if not (Conn.halted conn) then raise Conn.Connection_should_be_closed;

  match Conn.switch conn with Some switch -> `upgrade switch | None -> `close

module Req_logger = Req_logger

let logger ~level () = trail (module Req_logger) (Req_logger.make ~level ())

module Request_id = Request_id

let request_id args = trail (module Request_id) args
