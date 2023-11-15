open Connection

let run conn _ctx =
  let rnd = Riot.random () in
  let req_id = Uuidm.(v4_gen rnd () |> to_string) in
  conn |> with_header "x-request-id" req_id
