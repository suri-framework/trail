module type Intf = sig
  val send :
    Atacama.Socket.t ->
    Http.Request.t ->
    Http.Status.t ->
    Http.Header.t ->
    Bigstringaf.t ->
    unit
end

type t = (module Intf)

let send (module A : Intf) socket req status headers body =
  A.send socket req status headers body
