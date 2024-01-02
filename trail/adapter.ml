open Riot

module type Intf = sig
  val send : Atacama.Connection.t -> Request.t -> Response.t -> unit
  val send_chunk : Atacama.Connection.t -> Request.t -> IO.Buffer.t -> unit
end

type t = (module Intf)
