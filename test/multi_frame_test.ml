open Riot

let test_single_pong () =
  let ser = Trail.Frame.Request.serialize Ping in
  let raw = Bytestring.to_string ser in
  let res = Trail.Frame.Response.deserialize raw in
  match res with
  | Some (`ok Ping, "") -> ()
  | _ -> Alcotest.fail "Invalid response"

let test_pong_with_other_message () =
  let ser = Trail.Frame.Response.serialize Ping in
  (* let bytes = Bytestring.to_string ser in *)
  (* let repr = *)
  (*   String.fold_left (fun acc b -> acc ^ Fmt.str "%d " (Char.code b)) "" bytes *)
  (* in *)
  (* failwith (Fmt.str "BYTES -> %s@." repr) *)
  let raw = Bytestring.to_string ser in
  (* Add a null byte separator *)
  let raw = raw ^ Bytes.to_string Bytes.empty in
  (* Append a hello world text *)
  let text =
    Trail.Frame.Response.serialize
      (Text { fin = true; compressed = false; payload = "hello, world" })
    |> Bytestring.to_string
  in
  let raw = raw ^ text in
  let res = Trail.Frame.Response.deserialize raw in
  let text_repr =
    String.fold_left (fun acc b -> acc ^ Fmt.str "%d " (Char.code b)) "" text
  in
  match res with
  | Some (`ok Ping, remaining) when remaining = text -> ()
  | Some (`ok Ping, _) ->
      Alcotest.fail (Fmt.str "Expected remaining = %s | %s" text text_repr)
  | _ -> Alcotest.fail "Invalid response"

let () =
  Riot.run @@ fun () ->
  let _ = Logger.start () in
  Logger.set_log_level (Some Debug);

  let open Alcotest in
  run "Utils"
    [
      ( "start",
        [
          test_case "alcotest" `Quick (fun () ->
              Alcotest.(check int "1 + 1 = 2" 2 (1 + 1)));
          test_case "single pong" `Quick test_single_pong;
          test_case "pong + other msg" `Quick test_pong_with_other_message;
        ] );
    ]
