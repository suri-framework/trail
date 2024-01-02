open Riot

type t = {
  headers : Http.Header.t;
  meth : Http.Method.t;
  uri : Uri.t;
  version : Http.Version.t;
  encoding : Http.Transfer.encoding;
  body : IO.Buffer.t option;
}

let make ?body ?(meth = `GET) ?(version = `HTTP_1_1) ?(headers = []) uri =
  let uri = Uri.of_string uri in
  let headers = Http.Header.of_list headers in
  let encoding = Http.Header.get_transfer_encoding headers in
  { headers; uri; meth; version; encoding; body }

let pp fmt ({ headers; meth; uri; version; _ } : t) =
  let req = Http.Request.make ~meth ~headers ~version (Uri.to_string uri) in
  Http.Request.pp fmt req

let from_httpaf req =
  let open Httpaf.Request in
  let version =
    Httpaf.Version.to_string req.version |> Http.Version.of_string
  in
  let headers = Httpaf.Headers.to_list req.headers |> Http.Header.of_list in
  let meth = (req.meth :> Http.Method.t) in
  let encoding = Http.Header.get_transfer_encoding headers in
  let uri = Uri.of_string req.target in
  { body = None; headers; meth; uri; version; encoding }

let is_keep_alive t =
  match Http.Header.connection t.headers with
  | Some `Close -> false
  | Some `Keep_alive -> true
  | Some (`Unknown _) -> false
  | None -> Http.Version.compare t.version `HTTP_1_1 = 0
