open Riot

exception Connection_should_be_closed

type t = {
  adapter : Adapter.t;
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

type status
type body

let make adapter conn (req : Request.t) =
  {
    adapter;
    body = IO.Buffer.with_capacity 1024;
    halted = false;
    headers = [];
    req;
    conn;
    status = `OK;
    before_send_cbs = [];
    path = Uri.to_string req.uri;
    meth = req.meth;
    switch = None;
  }

let halted t = t.halted
let run_callbacks fns t = fns |> List.rev |> List.iter (fun cb -> cb t)

let register_before_send fn t =
  { t with before_send_cbs = fn :: t.before_send_cbs }

let with_header header value t =
  { t with headers = (header, value) :: t.headers }

let with_body body t =
  let len = String.length body in
  let body = if len > 0 then IO.Buffer.of_string body else t.body in
  { t with body }

let with_status status t = { t with status }
let respond ~status ?(body = "") t = t |> with_status status |> with_body body

let send ({ adapter = (module A); conn; req; status; headers; body; _ } as t) =
  run_callbacks t.before_send_cbs t;
  let res = Response.(make status ~body ~headers ()) in
  let _ = A.send conn req res in
  { t with halted = true }

let send_response status ?body t = respond t ~status ?body |> send

let send_chunked status ({ adapter = (module A); conn; req; _ } as t) =
  let t =
    t |> with_header "transfer-encoding" "chunked" |> with_status status
  in
  let res = Response.(make t.status ~headers:t.headers ()) in
  let _ = A.send conn req res in
  t

let chunk chunk ({ adapter = (module A); conn; req; _ } as t) =
  let _ = A.send_chunk conn req (IO.Buffer.of_string chunk) in
  t

let close t = { t with halted = true }
let upgrade switch t = { t with switch = Some switch; halted = true }
let switch t = t.switch
