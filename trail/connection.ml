open Riot

exception Connection_should_be_closed

type t = {
  adapter : Adapter.t;
  body : IO.Buffer.t;
  halted : bool;
  path : string;
  meth : Http.Method.t;
  headers : Http.Header.t;
  req : Http.Request.t;
  socket : Atacama.Socket.t;
  status : Http.Status.t;
  before_send_cbs : (t -> unit) list;
}

type status
type body

let make adapter socket req =
  {
    adapter;
    body = IO.Buffer.with_capacity 1024;
    halted = false;
    headers = Http.Header.init ();
    req;
    socket;
    status = `OK;
    before_send_cbs = [];
    path = Http.Request.resource req;
    meth = Http.Request.meth req;
  }

let halted t = t.halted
let run_callbacks fns t = fns |> List.rev |> List.iter (fun cb -> cb t)

let register_before_send fn t =
  { t with before_send_cbs = fn :: t.before_send_cbs }

let with_header header value t =
  { t with headers = Http.Header.add t.headers header value }

let with_body body t =
  let len = String.length body in
  let body = if len > 0 then IO.Buffer.of_string body else t.body in
  { t with body }

let with_status status t = { t with status }
let respond ~status ?(body = "") t = t |> with_status status |> with_body body

let send ({ adapter; socket; req; status; headers; body; _ } as t) =
  run_callbacks t.before_send_cbs t;
  Adapter.send adapter socket req status headers body;
  { t with halted = true }

let send_response ~status ?body t = respond t ~status ?body |> send
