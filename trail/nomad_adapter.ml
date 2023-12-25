open Riot
open Nomad

let send conn req status headers body =
  let headers =
    Http.Header.add headers "content-length"
      (body |> IO.Buffer.length |> string_of_int)
  in
  let version = Http.Request.version req in
  let res = Http.Response.make ~version ~status ~headers () in
  let res = Http1.to_string res (IO.Buffer.to_string body) in
  Logger.debug (fun f -> f "res:\n%s" (IO.Buffer.to_string res));
  let _bytes = Atacama.Socket.send conn res |> Result.get_ok in
  ()
