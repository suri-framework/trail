open Riot

module Logger = Logger.Make (struct
  let namespace = [ "trail"; "conn" ]
end)

exception Connection_should_be_closed

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

type status
type body

let make adapter conn (req : Request.t) =
  let peer = Atacama.Connection.peer conn in
  let peer = { ip = Net.Addr.ip peer; port = Net.Addr.port peer } in
  {
    adapter;
    before_send_cbs = [];
    after_send_cbs = [];
    conn;
    halted = false;
    chunked = false;
    headers = [];
    meth = req.meth;
    path = Uri.path req.uri;
    params = [];
    peer;
    req;
    resp_body = Bytestring.empty;
    status = `OK;
    switch = None;
  }

let halted t = t.halted
let run_callbacks fns t = fns |> List.rev |> List.iter (fun cb -> cb t)

let register_before_send fn t =
  { t with before_send_cbs = fn :: t.before_send_cbs }

let register_after_send fn t =
  { t with after_send_cbs = fn :: t.after_send_cbs }

let with_header header value t =
  { t with headers = (header, value) :: t.headers }

let with_body resp_body t = { t with resp_body }
let with_status status t = { t with status }

let respond ~status ?(body = {%b||}) t =
  t |> with_status status |> with_body body

let send
    ({ adapter = (module A); conn; req; status; headers; resp_body = body; _ }
     as t) =
  run_callbacks t.before_send_cbs t;
  let res = Response.(make status ~version:req.version ~body ~headers ()) in
  let _ = A.send conn req res in
  run_callbacks t.after_send_cbs t;
  { t with halted = true }

let send_status status t = respond t ~status |> send
let send_response status body t = respond t ~status ~body |> send

let inform status headers ({ adapter = (module A); conn; req; _ } as t) =
  let res = Response.(make status ~version:req.version ~headers ()) in
  let _ = A.send conn req res in
  t

let send_file status ?off ?len ~path
    ({ adapter = (module A); conn; req; _ } as t) =
  let res = Response.(make status ~version:req.version ~headers:t.headers ()) in
  let _ = A.send_file conn req res ?off ?len ~path () in
  { t with halted = true }

let send_chunked status ({ adapter = (module A); conn; req; _ } as t) =
  let t =
    t |> with_header "transfer-encoding" "chunked" |> with_status status
  in
  let res =
    Response.(make t.status ~version:req.version ~headers:t.headers ())
  in
  let _ = A.send conn req res in
  { t with chunked = true }

let chunk chunk ({ adapter = (module A); conn; req; _ } as t) =
  let _ = A.send_chunk conn req chunk in
  t

let set_params params t = { t with params }

type read_result =
  | Ok of t * Bytestring.t
  | More of t * Bytestring.t
  | Error of
      t
      * [ `Excess_body_read | `Closed | `Process_down | `Timeout | IO.io_error ]

let close ({ adapter = (module A); conn; _ } as t) =
  if t.chunked then A.close_chunk conn;
  { t with halted = true }

let upgrade switch t = { t with switch = Some switch; halted = true }
let switch t = t.switch

let read_body ?limit ({ adapter = (module A); conn; req; _ } as t) =
  Logger.trace (fun f -> f "reading body");
  match A.read_body ?limit conn req with
  | Adapter.Ok (req, body) -> Ok ({ t with req }, body)
  | Adapter.More (req, body) -> More ({ t with req }, body)
  | Adapter.Error (req, reason) -> Error ({ t with req }, reason)
