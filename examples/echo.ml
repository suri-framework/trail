[@@@warning "-8"]

open Riot

let trail =
  Trail.
    [ (fun conn -> Conn.send_response ~status:`OK ~body:"hello world" conn) ]

let () =
  Riot.run @@ fun () ->
  let (Ok pid) = Trail.start_link ~port:2112 trail in
  wait_pids [ pid ]
