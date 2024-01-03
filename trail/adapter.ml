open Riot

type read_result =
  | Ok of Request.t * IO.Buffer.t
  | More of Request.t * IO.Buffer.t
  | Error of
      Request.t
      * [ `Excess_body_read
        | `Closed
        | `Process_down
        | `Timeout
        | IO.unix_error ]

module type Intf = sig
  val send : Atacama.Connection.t -> Request.t -> Response.t -> unit
  val send_chunk : Atacama.Connection.t -> Request.t -> IO.Buffer.t -> unit

  val send_file :
    Atacama.Connection.t ->
    Request.t ->
    Response.t ->
    ?off:int ->
    ?len:int ->
    path:string ->
    unit ->
    unit

  val read_body :
    ?limit:int ->
    ?read_size:int ->
    Atacama.Connection.t ->
    Request.t ->
    read_result
end

type t = (module Intf)
