open Riot

let trail =
  Trail.
    [
      logger ~level:Debug ();
      (fun conn -> Conn.send_response `OK ~body:"hello world" conn);
    ]

[@@@warning "-8"]

let () =
  Riot.run @@ fun () ->
  Logger.set_log_level (Some Info);
  let (Ok _) = Logger.start () in
  sleep 0.1;
  let port = 2112 in
  let (Ok pid) = Nomad.start_link ~port trail in
  Logger.info (fun f -> f "Listening on 0.0.0.0:%d" port);
  wait_pids [ pid ]
