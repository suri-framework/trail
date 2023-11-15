open Riot

let trail =
  Trail.
    [
      Logger.run;
      (fun conn _ctx -> Conn.send_response ~status:`OK ~body:"hello world" conn);
    ]

[@@@warning "-8"]
let () = Riot.run @@ fun () ->
  Logger.set_log_level (Some Info);
  let (Ok _) = Logger.start () in
  sleep 0.1;
  let port = 2112 in
  let (Ok pid) = Trail.start_link ~port trail 0 in
  Logger.info (fun f -> f "Listening on 0.0.0.0:%d" port);
  wait_pids [ pid ]

