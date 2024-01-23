open Riot

type upgrade_opts = { do_upgrade : bool }

type ('state, 'error) handle_result =
  [ `push of Frame.t list * 'state | `ok of 'state | `error of 'state * 'error ]

module type Intf = sig
  type state
  type args

  val init : args -> (state, [> `Unknown_opcode of int ]) handle_result

  val handle_frame :
    Frame.t ->
    Atacama.Connection.t ->
    state ->
    (state, [> `Unknown_opcode of int ]) handle_result

  val handle_message :
    Message.t -> state -> (state, [> `Unknown_opcode of int ]) handle_result
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
  match H.init args with
  | `ok state -> `continue (conn, Sock { handler; args; state = Some state })
  | `error (_state, err) -> `error (conn, err)
  | _ -> failwith "can't send frames on initialization"

let handle_frame (Sock ({ handler = (module H); state; _ } as sock)) frame conn
    =
  match H.handle_frame frame conn (Option.get state) with
  | `ok state -> `continue (conn, Sock { sock with state = Some state })
  | `error (_state, err) -> `error (conn, err)
  | `push (frames, state) ->
      `push (frames, Sock { sock with state = Some state })

let handle_message (Sock ({ handler = (module H); state; _ } as sock)) msg conn
    =
  match H.handle_message msg (Option.get state) with
  | `ok state -> `continue (conn, Sock { sock with state = Some state })
  | `error (_state, err) -> `error (conn, err)
  | `push (frames, state) ->
      `push (frames, Sock { sock with state = Some state })

module Default = struct
  let handle_frame _frame _conn _state = failwith "unimplemented"
  let handle_message _msg _state = failwith "unimplemented"
end
