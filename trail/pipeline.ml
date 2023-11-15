type 'ctx opts = { ctx : 'ctx }
type 'ctx trail = Connection.t -> 'ctx opts -> Connection.t
type _ t = [] : 'ctx t | ( :: ) : 'ctx trail * 'ctx t -> 'ctx t

let rec run_pipeline t ctx (conn : Connection.t) =
  match t with
  | [] -> conn
  | trail :: t ->
      let conn = trail conn ctx in
      if Connection.halted conn then conn else run_pipeline t ctx conn

let run ctx (conn : Connection.t) t =
  if Connection.halted conn then conn else run_pipeline t ctx conn
