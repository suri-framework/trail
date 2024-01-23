open Riot

let trail =
  let open Trail in
  let open Router in
  [
    use (module Logger) Logger.(args ~level:Debug ());
    router
      [
        get "/" (fun conn -> Conn.send_response `OK {%b|"hello world"|} conn);
        (* socket "/" (module My_handler); *)
        scope "/api"
          [
            get "/version" (fun conn ->
                Conn.send_response `OK {%b|"none"|} conn);
            get "/version" (fun conn ->
                Conn.send_response `OK {%b|"none"|} conn);
            get "/version" (fun conn ->
                Conn.send_response `OK {%b|"none"|} conn);
          ];
      ];
  ]

[@@@warning "-8"]

let () =
  Riot.run @@ fun () ->
  Logger.set_log_level (Some Info);
  let (Ok _) = Logger.start () in
  sleep 0.1;
  let port = 2112 in
  let handler = Nomad.trail trail in
  let (Ok pid) = Nomad.start_link ~port ~handler () in
  Logger.info (fun f -> f "Listening on 0.0.0.0:%d" port);
  wait_pids [ pid ]
