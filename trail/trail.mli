(** # Trail

Trail is a minimalistic, composable framework for building HTTP/S and WebSocket
servers, inspired by [Plug][plug] and [WebSock][websock]. It provides its users with a small set of
abstractions for building _trails_ that can be assembled to handle a request.

To create a Trail, you can use the syntax `Trail.[fn1;fn2;fn3;...]`, where each
function takes a connection object and produces a new connection object.

For example:

```ocaml
Trail.[
  logger {level=Debug};
  request_id {kind=Uuid_v4};
  cqrs_token ();
  session {salt="3FBYQ5+B"};
  (fun conn req -> conn |> send_resp ~status:`OK ~body:"hello world!");
]
```

Trail also comes with support for [Riot][riot], and to start a Trail supervision tree you can call `Trail.start_link ~port trail`.

[riot]: https://github.com/leostera/riot
[plug]: https://hexdocs.pm/plug/readme.html
[websock]: https://hexdocs.pm/websock/readme.html
*)

open Riot

module Frame : sig
  type t =
    | Continuation of { fin : bool; compressed : bool; payload : string }
    | Text of { fin : bool; compressed : bool; payload : string }
    | Binary of { fin : bool; compressed : bool; payload : string }
    | Connection_close of { fin : bool; compressed : bool; payload : string }
    | Ping
    | Pong

  val pp : Format.formatter -> t -> unit
  val unmask : int32 -> string -> string

  val make :
    fin:bool ->
    compressed:bool ->
    rsv:int ->
    opcode:int ->
    mask:int32 ->
    payload:string ->
    [> `error of [> `Unknown_opcode of int ] | `ok of t ]

  val deserialize :
    ?max_frame_size:int ->
    string ->
    ([> `error of [> `Unknown_opcode of int ]
     | `more of Riot.IO.Buffer.t
     | `ok of t ]
    * string)
    option

  val serialize : t -> Riot.IO.Buffer.t
end

module Sock : sig
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

  type t

  val make : (module Intf with type args = 'a and type state = 'b) -> 'a -> t

  val init :
    t ->
    Atacama.Connection.t ->
    [> `continue of Atacama.Connection.t * t
    | `error of Atacama.Connection.t * [> `Unknown_opcode of int ] ]

  val handle_frame :
    t ->
    Frame.t ->
    Atacama.Connection.t ->
    [ `close of Atacama.Connection.t
    | `continue of Atacama.Connection.t
    | `error of Atacama.Connection.t * [> `Unknown_opcode of int ]
    | `push of Frame.t list ]
end

module Response : sig
  type t = {
    status : Http.Status.t;
    headers : Http.Header.t;
    version : Http.Version.t;
  }

  val make :
    Http.Status.t ->
    ?headers:(string * string) list ->
    ?version:Http.Version.t ->
    unit ->
    t

  val pp : Format.formatter -> t -> unit
  val to_buffer : ?body:IO.Buffer.t -> t -> IO.Buffer.t
end

module Request : sig
  type t = {
    headers : Http.Header.t;
    meth : Http.Method.t;
    uri : Uri.t;
    version : Http.Version.t;
    encoding : Http.Transfer.encoding;
  }

  val make :
    ?meth:Http.Method.t ->
    ?version:Http.Version.t ->
    ?headers:(string * string) list ->
    string ->
    t

  val pp : Format.formatter -> t -> unit
  val is_keep_alive : t -> bool
end

(** The `Conn` module includes functions for handling an ongoing connection. *)
module Conn : sig
  type t = {
    body : IO.Buffer.t;
    halted : bool;
    path : string;
    meth : Http.Method.t;
    headers : (string * string) list;
    req : Request.t;
    conn : Atacama.Connection.t;
    status : Http.Status.t;
    before_send_cbs : (t -> unit) list;
    switch : [ `websocket of Sock.upgrade_opts * Sock.t | `h2c ] option;
  }
  (** The core connection type.

      A `Conn.t` represents an active connection, and is the main value passed
      across the trails.
   *)

  val register_before_send : (t -> unit) -> t -> t
  (** `register_before_send fn` will call the function `fn` with the current
      connection immediately before any calls to `send`.

      This is useful for measuring, performing sanity checks on the connection,
      or just for logging.
  *)

  val with_header : string -> string -> t -> t
  (** `with_header header value conn` will add a new header named `header` and
      set it to the value `value`. Note that only the new connection object
      will have this header set.
  *)

  val with_body : string -> t -> t
  (** `with_body body conn` will set the response body to `body` *)

  val with_status : Http.Status.t -> t -> t
  (** `with_status status conn` will set the response status to `status` *)

  val respond : status:Http.Status.t -> ?body:string -> t -> t
  (** Set the status code and optionally the response body for a connection. *)

  val send : t -> t
  (** Send a connection. Typically within a trail, once `send` is called,
      the rest of the trails will be skipped.

      If the connection has already been sent, this function will raise an
      exception.

      If the returned connection object is ignored, and the old connection
      object is used, the underlying socket may already be closed and other
      operations would raise.
  *)

  val send_response : Http.Status.t -> ?body:string -> t -> t
  (** Convenience function to set a response and send it in one go. *)

  val upgrade : [ `h2c | `websocket of Sock.upgrade_opts * Sock.t ] -> t -> t
  (** [upgrade p conn] upgrades the connection [conn] to the new protocol [p].
   *)
end

type trail = Conn.t -> Conn.t
(** A trail is a function that given a connection and some options, will
    produce a new connection object.
*)

type t = trail list
(** The `Trail.t` is the type of the trail _pipelines_.

    You can create new pipelines by using the syntax:

    ```ocaml
    Trail.[
      logger ~level:Info ();
      request_id { kind:Uuid_v4 };
      my_authentication;
      my_authorization;
      my_handler
    ]
    ```

 *)

module type Intf = sig
  type args
  type state

  val init : args -> state
  val call : Conn.t -> state -> Conn.t
end

val trail : (module Intf with type args = 'args) -> 'args -> trail

module Req_logger : sig
  type level = Logger.level
  type args = { level : Logger.level; id : int Atomic.t }
end

val logger : level:Logger.level -> unit -> trail

module Request_id : sig
  type id_kind = Uuid_v4
  type args = { kind : id_kind }
end

val request_id : Request_id.args -> trail

val handler :
  (Conn.t -> Conn.t) list ->
  Atacama.Connection.t ->
  Request.t ->
  [> `close | `upgrade of [ `h2c | `websocket of Sock.upgrade_opts * Sock.t ] ]
