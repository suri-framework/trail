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
     | `more of Bytestring.t
     | `ok of t ]
    * string)
    option

  val serialize : t -> Bytestring.t
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
    body : Bytestring.t;
  }

  val make :
    Http.Status.t ->
    ?headers:(string * string) list ->
    ?version:Http.Version.t ->
    ?body:Bytestring.t ->
    unit ->
    t

  val pp : Format.formatter -> t -> unit

  type response =
    ?headers:(string * string) list ->
    ?version:Http.Version.t ->
    ?body:Bytestring.t ->
    unit ->
    t

  val accepted : response
  val already_reported : response
  val bad_gateway : response
  val bad_request : response
  val bandwidth_limit_exceeded : response
  val blocked_by_windows_parental_controls : response
  val checkpoint : response
  val client_closed_request : response
  val conflict : response
  val continue : response
  val created : response
  val enhance_your_calm : response
  val expectation_failed : response
  val failed_dependency : response
  val forbidden : response
  val found : response
  val gateway_timeout : response
  val gone : response
  val http_version_not_supported : response
  val im_a_teapot : response
  val im_used : response
  val insufficient_storage : response
  val internal_server_error : response
  val length_required : response
  val locked : response
  val loop_detected : response
  val method_not_allowed : response
  val moved_permanently : response
  val multi_status : response
  val multiple_choices : response
  val network_authentication_required : response
  val network_connect_timeout_error : response
  val network_read_timeout_error : response
  val no_content : response
  val no_response : response
  val non_authoritative_information : response
  val not_acceptable : response
  val not_extended : response
  val not_found : response
  val not_implemented : response
  val not_modified : response
  val ok : response
  val partial_content : response
  val payment_required : response
  val permanent_redirect : response
  val precondition_failed : response
  val precondition_required : response
  val processing : response
  val proxy_authentication_required : response
  val request_entity_too_large : response
  val request_header_fields_too_large : response
  val request_timeout : response
  val request_uri_too_long : response
  val requested_range_not_satisfiable : response
  val reset_content : response
  val retry_with : response
  val see_other : response
  val service_unavailable : response
  val switch_proxy : response
  val switching_protocols : response
  val temporary_redirect : response
  val too_many_requests : response
  val unauthorized : response
  val unprocessable_entity : response
  val unsupported_media_type : response
  val upgrade_required : response
  val use_proxy : response
  val variant_also_negotiates : response
  val wrong_exchange_server : response
end

module Request : sig
  type body_reader =
    Atacama.Connection.t ->
    [ `ok of Bytestring.t | `more of Bytestring.t | `error of IO.io_error ]

  type t = {
    body_remaining : int;
    buffer : Bytestring.t;
    encoding : Http.Transfer.encoding;
    headers : Http.Header.t;
    meth : Http.Method.t;
    path : string list;
    query : (string * string list) list;
    uri : Uri.t;
    version : Http.Version.t;
  }

  val make :
    ?body:Bytestring.t ->
    ?meth:Http.Method.t ->
    ?version:Http.Version.t ->
    ?headers:(string * string) list ->
    string ->
    t

  val from_http : Http.Request.t -> t
  val from_httpaf : Httpaf.Request.t -> t
  val pp : Format.formatter -> t -> unit
  val is_keep_alive : t -> bool

  exception Invalid_content_header

  val content_length : t -> int option
  val body_encoding : t -> Http.Transfer.encoding
end

module Adapter : sig
  type read_result =
    | Ok of Request.t * Bytestring.t
    | More of Request.t * Bytestring.t
    | Error of
        Request.t
        * [ `Excess_body_read
          | `Closed
          | `Process_down
          | `Timeout
          | IO.io_error ]

  module type Intf = sig
    val send : Atacama.Connection.t -> Request.t -> Response.t -> unit
    val send_chunk : Atacama.Connection.t -> Request.t -> Bytestring.t -> unit
    val close_chunk : Atacama.Connection.t -> unit

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
end

(** The `Conn` module includes functions for handling an ongoing connection. *)
module Conn : sig
  type peer = { ip : Net.Addr.tcp_addr; port : int }

  type t = {
    adapter : Adapter.t;
    before_send_cbs : (t -> unit) list;
    after_send_cbs : (t -> unit) list;
    conn : Atacama.Connection.t;
    halted : bool;
    chunked : bool;
    headers : (string * string) list;
    meth : Http.Method.t;
    path : string;
    params : (string * string) list;
    peer : peer;
    req : Request.t;
    resp_body : Bytestring.t;
    status : Http.Status.t;
    switch : [ `websocket of Sock.upgrade_opts * Sock.t | `h2c ] option;
  }
  (** The core connection type.

      A `Conn.t` represents an active connection, and is the main value passed
      across the trails.
   *)

  val register_after_send : (t -> unit) -> t -> t

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

  val with_body : Bytestring.t -> t -> t
  (** `with_body body conn` will set the response body to `body` *)

  val with_status : Http.Status.t -> t -> t
  (** `with_status status conn` will set the response status to `status` *)

  val respond : status:Http.Status.t -> ?body:Bytestring.t -> t -> t
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

  val send_status : Http.Status.t -> t -> t
  (** Send a response with a status but no body *)

  val send_response : Http.Status.t -> Bytestring.t -> t -> t
  (** Convenience function to set a response and send it in one go. *)

  val send_chunked : Http.Status.t -> t -> t
  (** [send_chunked `OK conn] initializes a stream response in the connection.
      
      You can use the [chunk data conn] function to send more data.
  *)

  val chunk : Bytestring.t -> t -> t
  (** [chunk data conn] will send data to the streamed connection.
  *)

  val set_params : (string * string) list -> t -> t
  (** [set_params params conn] updates the connection with parameters. Note
      that this is primarily useful when building connection values that will
      be handled by user trails.
  *)

  type read_result =
    | Ok of t * Bytestring.t
    | More of t * Bytestring.t
    | Error of
        t
        * [ `Excess_body_read
          | `Closed
          | `Process_down
          | `Timeout
          | IO.io_error ]

  val read_body : ?limit:int -> t -> read_result
  (** [read_body ?limit conn] will do a read on the body and return a buffer
      with it. If `limit` is set, the response will be at most of length
      `limit`.

      If there is no more to read, this returns a [Ok (conn, buf)].
      If there is more to be read, this returns a [More (conn, buf)].
      On errors, this returns an [Error (conn, reason)].
  *)

  val send_file : Http.Status.t -> ?off:int -> ?len:int -> path:string -> t -> t
  (** [send_file code path conn] sets up the connection [conn] and transfers
      the file at [path] with status code [code].
  *)

  val inform : Http.Status.t -> (string * string) list -> t -> t
  (** [inform status headers] sends an information message back to the client
      and does not close the connection.
  *)

  val upgrade : [ `h2c | `websocket of Sock.upgrade_opts * Sock.t ] -> t -> t
  (** [upgrade p conn] upgrades the connection [conn] to the new protocol [p].
   *)

  val close : t -> t
  (** [close conn] will mark this connection as closed. *)
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
  Adapter.t ->
  (Conn.t -> Conn.t) list ->
  Atacama.Connection.t ->
  Request.t ->
  [> `close | `upgrade of [ `h2c | `websocket of Sock.upgrade_opts * Sock.t ] ]
