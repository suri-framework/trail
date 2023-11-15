type trail = Connection.t -> Connection.t
type t = trail list

let rec run_pipeline t (conn : Connection.t) =
  match t with
  | [] -> conn
  | trail :: t ->
      let conn = trail conn in
      if Connection.halted conn then conn else run_pipeline t conn

let run (conn : Connection.t) t =
  if Connection.halted conn then conn else run_pipeline t conn
