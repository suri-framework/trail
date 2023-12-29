open Riot

type t = {
  status : Http.Status.t;
  headers : Http.Header.t;
  version : Http.Version.t;
}

let pp fmt ({ headers; version; status } : t) =
  let res = Http.Response.make ~headers ~version ~status () in
  Http.Response.pp fmt res

let make status ?(headers = []) ?(version = `HTTP_1_1) () =
  { status; version; headers = Http.Header.of_list headers }

let to_buffer ?body { status; headers; version } =
  let version = version |> Http.Version.to_string |> Httpaf.Version.of_string in
  let status = status |> Http.Status.to_int |> Httpaf.Status.of_code in

  let headers =
    match body with
    | Some body ->
        let content_length =
          Http.Header.get headers "content-length"
          |> Option.value ~default:(IO.Buffer.length body |> Int.to_string)
        in
        Http.Header.add headers "content-length" content_length
    | None -> headers
  in

  let headers = headers |> Http.Header.to_list |> Httpaf.Headers.of_list in

  let res = Httpaf.Response.create ~version ~headers status in
  let buf = Faraday.create (1024 * 4) in
  Httpaf.Httpaf_private.Serialize.write_response buf res;

  (match body with
  | Some body ->
      let Cstruct.{ buffer = ba; len; off } = IO.Buffer.as_cstruct body in
      Faraday.write_bigstring buf ~off ~len ba;
      Faraday.write_string buf "\n\n0\n\n"
  | None -> ());

  let ba = Faraday.serialize_to_bigstring buf in
  let len = Bigstringaf.length ba in
  let cs = Cstruct.of_bigarray ~off:0 ~len ba in
  IO.Buffer.of_cstruct ~filled:len cs
