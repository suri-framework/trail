open Riot
module Conn = Connection

open Logger.Make (struct
  let namespace = [ "trail"; "cors" ]
end)

type args = {
  origin : string;
  credentials : bool;
  max_age : int64;
  headers : string list;
  expose : string list;
  methods : string list;
  send_preflight_response : bool;
}

type state = args

let default_headers =
  [
    "Authorization";
    "Content-Type";
    "Accept";
    "Origin";
    "User-Agent";
    "DNT";
    "Cache-Control";
    "X-Mx-ReqToken";
    "Keep-Alive";
    "X-Requested-With";
    "If-Modified-Since";
    "X-CSRF-Token";
  ]

let default_methods = [ "GET"; "POST"; "PUT"; "PATCH"; "DELETE"; "OPTIONS" ]

let config ?(origin = "*") ?(credentials = true) ?(max_age = 1_728_000L)
    ?(headers = default_headers) ?(expose = []) ?(methods = default_methods)
    ?(send_preflight_response = true) () =
  {
    origin;
    credentials;
    max_age;
    headers;
    expose;
    methods;
    send_preflight_response;
  }

let init args = args

let call (conn : Conn.t) t =
  match conn.req.meth with
  | `OPTIONS ->
      conn
      |> Conn.with_header "access-control-allow-origin" t.origin
      |> Conn.with_header "access-control-allow-credentials"
           (Bool.to_string t.credentials)
      |> Conn.with_header "access-control-max-age" (Int64.to_string t.max_age)
      |> Conn.with_header "access-control-allow-headers"
           (String.concat "," t.headers)
      |> Conn.with_header "access-control-allow-methods"
           (String.concat "," t.methods)
  | _ ->
      conn
      |> Conn.with_header "access-control-allow-origin" t.origin
      |> Conn.with_header "access-control-allow-credentials"
           (Bool.to_string t.credentials)
      |> Conn.with_header "access-control-expose-headers"
           (String.concat "," t.expose)
