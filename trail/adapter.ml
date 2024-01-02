module type Intf = sig
  val send : Atacama.Connection.t -> Request.t -> Response.t -> unit
end

type t = (module Intf)
