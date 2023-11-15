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
    socket : Caravan.Socket.t;
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

type 'ctx opts = { ctx : 'ctx }

type 'ctx trail = Conn.t -> 'ctx opts -> Conn.t
(** A trail is a function that given a connection and some options, will
    produce a new connection object.
*)

type 'a t = [] : 'ctx t | ( :: ) : 'ctx trail * 'ctx t -> 'ctx t
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

val start_link :
  port:int ->
  ?adapter:Adapter.t ->
  'a t ->
  'a ->
  (Riot.Pid.t, [> `Supervisor_error ]) result
(** Starts a `Trail` supervision tree. *)

module Logger : sig
  val run : 'ctx trail
end

module Request_id : sig
  val run : 'ctx trail
end
