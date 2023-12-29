type upgrade_opts = { do_upgrade : bool }

module type Intf = sig
  type state
  type args

  val init :
    Atacama.Connection.t ->
    args ->
    [ `continue of Atacama.Connection.t * state
    | `error of Atacama.Connection.t * [> `Unknown_opcode of int ] ]

  val handle_frame :
    Frame.t ->
    Atacama.Connection.t ->
    state ->
    [ `push of Frame.t list
    | `continue of Atacama.Connection.t
    | `close of Atacama.Connection.t
    | `error of Atacama.Connection.t * [> `Unknown_opcode of int ] ]
end

type t =
  | Sock : {
      handler : (module Intf with type args = 'args and type state = 'state);
      args : 'args;
      state : 'state option;
    }
      -> t

let make handler args = Sock { handler; args; state = None }

let init (Sock { handler = (module H) as handler; args; _ }) conn =
  match H.init conn args with
  | `continue (conn, state) ->
      `continue (conn, Sock { handler; args; state = Some state })
  | `error (conn, err) -> `error (conn, err)

let handle_frame (Sock { handler = (module H); state; _ }) frame conn =
  H.handle_frame frame conn (Option.get state)
