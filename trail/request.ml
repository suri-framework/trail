open Riot

type t = {
  headers : Http.Header.t;
  meth : Http.Method.t;
  uri : Uri.t;
  version : Http.Version.t;
  encoding : Http.Transfer.encoding;
  body : IO.Buffer.t option;
  path : string list;
  query : (string * string list) list;
}

let make ?body ?(meth = `GET) ?(version = `HTTP_1_1) ?(headers = []) uri =
  let uri = Uri.of_string uri in
  let headers = Http.Header.of_list headers in
  let encoding = Http.Header.get_transfer_encoding headers in
  let path =
    match Uri.path uri |> String.split_on_char '/' with
    | "" :: path -> path
    | path -> path
  in
  let query = Uri.query uri in
  { headers; uri; meth; version; encoding; body; path; query }

let pp fmt ({ headers; meth; uri; version; _ } : t) =
  let req = Http.Request.make ~meth ~headers ~version (Uri.to_string uri) in
  Http.Request.pp fmt req

let from_http req =
  let meth = Http.Request.meth req in
  let headers = Http.Request.headers req |> Http.Header.to_list in
  let target = Http.Request.resource req in
  let version = Http.Request.version req in
  make ~meth ~version ~headers target

let from_httpaf req =
  let open Httpaf.Request in
  let version =
    Httpaf.Version.to_string req.version |> Http.Version.of_string
  in
  let headers = Httpaf.Headers.to_list req.headers in
  let meth = (req.meth :> Http.Method.t) in
  make ~meth ~version ~headers req.target

let is_keep_alive t =
  match Http.Header.get t.headers "connection" with
  | Some "keep_alive" -> true
  | _ -> false
