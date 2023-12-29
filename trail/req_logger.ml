open Riot
open Connection

type level = Logger.level
type args = { level : Logger.level; id : int Atomic.t }
type state = args

let make ~level () = { level; id = Atomic.make 0 }
let init args = args

let call conn args =
  let id = Atomic.fetch_and_add args.id 1 in
  Logger.info (fun f -> f "#%d %a %s" id Http.Method.pp conn.meth conn.path);
  let start_time = Ptime_clock.now () in
  conn
  |> register_before_send (fun conn ->
         let end_time = Ptime_clock.now () in
         let elapsed_time = Ptime.diff end_time start_time in
         Logger.info (fun f ->
             f "Sent %a in %a" Http.Status.pp conn.status Ptime.Span.pp
               elapsed_time))
