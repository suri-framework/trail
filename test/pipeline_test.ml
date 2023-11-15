[@@@warning "-8"]

open Riot

let trail =
  Trail.
    [
      logger { level = Debug };
      request_id { kind = Uuid_v4 };
      (fun conn -> Conn.send_response ~status:`OK ~body:"hello world" conn);
    ]

let main () =
  Logger.set_log_level (Some Info);
  let (Ok _) = Logger.start () in
  sleep 0.1;
  Logger.info (fun f -> f "starting nomad caravan");
  let (Ok pid) = Trail.start_link ~port:2112 trail in
  wait_pids [ pid ]

let () = Riot.run @@ main
