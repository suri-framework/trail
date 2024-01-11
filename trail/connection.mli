open Riot

exception Connection_should_be_closed

type peer = { ip : Net.Addr.tcp_addr; port : int }

type t = {
  adapter : Adapter.t;
  before_send_cbs : (t -> unit) list;
  conn : Atacama.Connection.t;
  halted : bool;
  chunked : bool;
  headers : (string * string) list;
  meth : Http.Method.t;
  path : string;
  peer : peer;
  req : Request.t;
  resp_body : Bytestring.t;
  status : Http.Status.t;
  switch : [ `websocket of Sock.upgrade_opts * Sock.t | `h2c ] option;
}

type status
type body

val make : Adapter.t -> Atacama.Connection.t -> Request.t -> t
val halted : t -> bool
val run_callbacks : ('a -> unit) list -> 'a -> unit
val register_before_send : (t -> unit) -> t -> t
val with_header : string -> string -> t -> t
val with_body : Bytestring.t -> t -> t
val with_status : Http.Status.t -> t -> t
val respond : status:Http.Status.t -> ?body:Bytestring.t -> t -> t
val send : t -> t
val send_status : Http.Status.t -> t -> t
val send_response : Http.Status.t -> Bytestring.t -> t -> t
val inform : Http.Status.t -> (string * string) list -> t -> t
val send_file : Http.Status.t -> ?off:int -> ?len:int -> path:string -> t -> t
val send_chunked : Http.Status.t -> t -> t
val chunk : Bytestring.t -> t -> t

type read_result =
  | Ok of t * Bytestring.t
  | More of t * Bytestring.t
  | Error of
      t
      * [ `Closed
        | `Excess_body_read
        | `Process_down
        | `Timeout
        | `Unix_error of Unix.error ]

val read_body : ?limit:int -> t -> read_result
val close : t -> t
val upgrade : [ `h2c | `websocket of Sock.upgrade_opts * Sock.t ] -> t -> t
val switch : t -> [ `h2c | `websocket of Sock.upgrade_opts * Sock.t ] option
