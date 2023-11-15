[@@@warning "-8"]

open Riot

let trail =
  Trail.
    [
      Logger.run;
      (fun conn _ctx -> Conn.send_response ~status:`OK ~body:"hello world" conn);
    ]

let () =
  Riot.run @@ fun () ->
  let (Ok pid) = Trail.start_link ~port:2112 trail 0 in
  wait_pids [ pid ]
