open Riot
module Conn = Connection

open Riot.Logger.Make (struct
  let namespace = [ "static" ]
end)

type args = { root : string; prefix : string }
type state = args

let init args = args

let call (conn : Conn.t) { root; prefix } =
  let rel_path = conn.req.path |> String.concat Stdlib.Filename.dir_sep in
  debug (fun f -> f "serving file at %S" rel_path);
  if String.starts_with ~prefix rel_path then (
    let abs_path = Stringext.replace_all rel_path ~pattern:prefix ~with_:root in
    let stat = File.stat abs_path in
    let file = File.open_read abs_path in
    let reader = File.to_reader file in
    let data =
      Bytestring.with_bytes ~capacity:stat.st_size (IO.read reader)
      |> Result.get_ok
    in
    File.close file;
    let mime_type = Magic_mime.lookup abs_path in
    conn
    |> Conn.with_header "content-type" mime_type
    |> Conn.send_response `OK data)
  else conn
