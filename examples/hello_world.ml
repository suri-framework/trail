open Riot
open Trail

module My_handler= struct
  type args = unit
  type state = unit

  let init conn () = `continue (conn, ())

  let handle_frame frame _conn _state = 
    Riot.Logger.info (fun f -> f "frame: %a" Frame.pp frame);
    `push []

end

let _trail =
  let open Router in
  [
    use (module Logger) Logger.(args ~level:Debug ());
    router
      [
        socket "/ws" (module My_handler) ();
        get "/" (fun conn -> Conn.send_response `OK {%b|"hello world"|} conn);
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
