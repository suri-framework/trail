exception Connection_should_be_closed

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

type status
type body

val make : Adapter.t -> Caravan.Socket.t -> Http.Request.t -> t
val halted : t -> bool
val run_callbacks : ('a -> unit) list -> 'a -> unit
val register_before_send : (t -> unit) -> t -> t
val with_header : string -> string -> t -> t
val respond : status:Http.Status.t -> ?body:string -> t -> t
val send : t -> t

val send_response :
  status:Http.Status.t -> ?body:string -> t -> t

