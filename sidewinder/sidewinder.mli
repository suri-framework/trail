module Html : sig
  type 'msg attr = [ `attr of string * string | `event of string -> 'msg ]

  val attr_id : 'a -> [> `attr of string * 'a ]
  val attr_type : 'a -> [> `attr of string * 'a ]

  type 'msg t =
    | El of { tag : string; attrs : 'msg attr list; children : 'msg t list }
    | Text of string
    | Splat of 'msg t list

  val list : 'msg t list -> 'msg t
  val button : on_click:'a attr -> children:'a t list -> unit -> 'a t
  val html : children:'a t list -> unit -> 'a t
  val body : children:'a t list -> unit -> 'a t
  val div : ?id:string -> children:'a t list -> unit -> 'a t
  val span : children:'a t list -> unit -> 'a t
  val script : ?id:string -> ?type_:string -> children:'a t list -> unit -> 'a t
  val event : 'a -> [> `event of 'a ]
  val string : string -> 'a t
  val int : int -> 'a t
  val to_string : 'msg t -> string
  val attrs_to_string : 'msg attr list -> string
  val event_handlers : [> `event of 'a ] list -> 'a list
  val map_action : ('msg_a -> 'msg_b) -> 'msg_a t -> 'msg_b t
end

module type Intf = sig
  type args
  type state
  type action

  val init : args -> state
  val handle_action : state -> action -> state
  val render : state:state -> unit -> action Html.t
end

module Default : sig
  val mount : path:string -> unit -> 'action Html.t
end

module Mount : functor (C : Intf) -> sig
  type args = C.args
  type state = { component : Riot.Pid.t }

  val init : C.args -> [> `ok of state ]

  val handle_frame :
    Trail.Frame.t ->
    'a ->
    state ->
    [> `ok of state | `push of Trail.Frame.t list * state ]

  val handle_message :
    Riot.Message.t -> 'a -> [> `ok of 'a | `push of Trail.Frame.t list * 'a ]
end

module Static : sig
  type args = unit
  type state = unit

  val init : unit -> unit
  val call : Trail.Conn.t -> unit -> Trail.Conn.t
end

val live :
  'args.
  string -> (module Intf with type args = 'args) -> 'args -> Trail.Router.t
