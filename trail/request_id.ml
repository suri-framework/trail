open Connection

type id_kind = Uuid_v4
type args = { kind : id_kind }
type state = args

let init args = args

let call conn args =
  let rnd = Riot.random () in
  let req_id =
    match args.kind with Uuid_v4 -> Uuidm.(v4_gen rnd () |> to_string)
  in
  conn |> with_header "x-request-id" req_id
