[@@@warning "-32"]

open Riot
open Trail

module My_handler = struct
  include Sock.Default

  type args = unit
  type state = unit

  let init () = `ok ()

  let handle_frame frame _conn state =
    Riot.Logger.info (fun f -> f "frame: %a" Frame.pp frame);
    `push ([], state)
end

(* $MDX part-begin=main *)
open Trail
open Router

let endpoint =
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
          ];
      ];
  ]
(* $MDX part-end *)
