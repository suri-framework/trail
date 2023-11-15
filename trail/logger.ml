open Riot
open Connection

type args = { level : Riot__.Logger.level }

let init args = args

let run conn _args =
  Logger.info (fun f -> f "%a %s" Http.Method.pp conn.meth conn.path);
  let start_time = Ptime_clock.now () in
  conn
  |> register_before_send (fun conn ->
         let end_time = Ptime_clock.now () in
         let elapsed_time = Ptime.diff end_time start_time in
         Logger.info (fun f ->
             f "Sent %a in %a" Http.Status.pp conn.status Ptime.Span.pp
               elapsed_time))
