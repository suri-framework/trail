(** # Trail

Trail is a minimalistic, composable framework for building HTTP/S servers, inspired by [Plug][plug]. It
provides its users with a small set of abstractions for building _trails_ that
can be assembled to handle a request.

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
*)

(** The `Conn` module includes functions for handling an ongoing connection. *)
module Conn : sig
  type t = {
    adapter : Adapter.t;
    body : Bigstringaf.t;
    halted : bool;
    path : string;
    meth : Http.Method.t;
    headers : Http.Header.t;
    req : Http.Request.t;
    socket : Atacama.Socket.t;
    status : Http.Status.t;
    before_send_cbs : (t -> unit) list;
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

  val with_body : Bigstringaf.t -> t -> t
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

  val send_response : status:Http.Status.t -> ?body:string -> t -> t
  (** Convenience function to set a response and send it in one go. *)
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
      Logger.run;
      Request_id.run;
      my_authentication;
      my_authorization;
      my_handler
    ]
    ```

 *)

module type Intf = sig
  type args

  val init : args -> args
  val run : Connection.t -> args -> Connection.t
end

val trail : (module Intf with type args = 'args) -> 'args -> trail

val start_link :
  port:int ->
  ?adapter:Adapter.t ->
  t ->
  (Riot.Pid.t, [> `Supervisor_error ]) result
(** Starts a `Trail` supervision tree. *)

module Logger : sig
  type args = { level : Riot__.Logger.level }
end

val logger : Logger.args -> trail

module Request_id : sig
  type id_kind = Uuid_v4
  type args = { kind : id_kind }
end

val request_id : Request_id.args -> trail
