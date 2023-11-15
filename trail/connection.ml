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

let make adapter socket req =
  {
    adapter;
    body = Bigstringaf.empty;
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

let respond ~status ?(body = "") t =
  let body =
    if body = "" then Bigstringaf.empty
    else Bigstringaf.of_string ~off:0 ~len:(String.length body) body
  in
  { t with status; body }

let send ({ adapter; socket; req; status; headers; body; _ } as t) =
  run_callbacks t.before_send_cbs t;
  Adapter.send adapter socket req status headers body;
  { t with halted = true }

let send_response ~status ?body t = respond t ~status ?body |> send
