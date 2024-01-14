open Riot

type body_reader =
  Atacama.Connection.t ->
  [ `ok of Bytestring.t | `more of Bytestring.t | `error of IO.io_error ]

type t = {
  body_remaining : int;
  buffer : Bytestring.t;
  encoding : Http.Transfer.encoding;
  headers : Http.Header.t;
  meth : Http.Method.t;
  path : string list;
  query : (string * string list) list;
  uri : Uri.t;
  version : Http.Version.t;
}

module StringSet = Set.Make (String)

exception Invalid_content_header

let content_length req =
  match Http.Header.get req.headers "content-length" with
  | None -> None
  | Some value -> (
      let values =
        String.split_on_char ',' value
        |> List.map String.trim |> StringSet.of_list |> StringSet.to_list
        |> List.map Int64.of_string_opt
      in
      match values with
      | [ Some first ] when first > 0L -> Some (first |> Int64.to_int)
      | _ :: _ -> raise Invalid_content_header
      | _ -> None)

let make ?(body = Bytestring.of_string "") ?(meth = `GET) ?(version = `HTTP_1_1)
    ?(headers = []) uri =
  let uri = Uri.of_string uri in
  let headers = Http.Header.of_list headers in
  let encoding = Http.Header.get_transfer_encoding headers in
  let path =
    (match Uri.path uri |> String.split_on_char '/' with
    | "" :: path -> path
    | path -> path)
    |> List.filter (fun part -> String.length part > 0)
  in
  let query = Uri.query uri in
  let req =
    {
      body_remaining = 0;
      buffer = body;
      encoding;
      headers;
      meth;
      path;
      query;
      uri;
      version;
    }
  in
  let body_remaining = content_length req |> Option.value ~default:0 in
  { req with body_remaining }

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

let body_encoding req = Http.Header.get_transfer_encoding req.headers
