open Riot

exception Fail

let response_serde frame =
  let ser = Trail.Frame.Response.serialize frame in
  Logger.debug (fun f -> f "ser: %S" (Bytestring.to_string ser));
  let raw = Bytestring.to_string ser in
  Logger.debug (fun f -> f "raw: %S" raw);
  let res = Trail.Frame.Response.deserialize raw in
  match res with
  | Some (`ok frame2, _) when Trail.Frame.equal frame frame2 ->
      Logger.debug (fun f -> f "frame_serde_test(response): OK");
      true
  | Some (`ok frame2, _) ->
      Logger.error (fun f ->
          f
            "frame_serde_test(response): frames are not the same\n\n\
             frame1: %a\n\n\
             frame2: %a" Trail.Frame.pp frame Trail.Frame.pp frame2);
      false
  | Some (`more bytes, _) ->
      Logger.error (fun f ->
          f "frame_serde_test(response): more bytes needed: %S"
            (Bytestring.to_string bytes));
      false
  | Some (`error (`Unknown_opcode op), _) ->
      Logger.error (fun f ->
          f "frame_serde_test(response): unknown opcode %d" op);
      false
  | None ->
      Logger.error (fun f ->
          f "frame_serde_test(response): could not even parse stuff?");
      false

let request_serde frame =
  let ser = Trail.Frame.Request.serialize frame in
  Logger.debug (fun f -> f "ser: %S" (Bytestring.to_string ser));
  let raw = Bytestring.to_string ser in
  Logger.debug (fun f -> f "raw: %S" raw);
  let res = Trail.Frame.Request.deserialize raw in
  match res with
  | Some (`ok frame2, _) when Trail.Frame.equal frame frame2 ->
      Logger.debug (fun f -> f "frame_serde_test(request): OK");
      true
  | Some (`ok frame2, _) ->
      Logger.error (fun f ->
          f
            "frame_serde_test(request): frames are not the same\n\n\
             frame1: %a\n\n\
             frame2: %a" Trail.Frame.pp frame Trail.Frame.pp frame2);
      false
  | Some (`more bytes, _) ->
      Logger.error (fun f ->
          f "frame_serde_test(request): more bytes needed: %S"
            (Bytestring.to_string bytes));
      false
  | Some (`error (`Unknown_opcode op), _) ->
      Logger.error (fun f ->
          f "frame_serde_test(request): unknown opcode %d" op);
      false
  | None ->
      Logger.error (fun f ->
          f "frame_serde_test(request): could not even parse stuff?");
      false

let frame_gen ~mode =
  let to_parts t =
    match t with
    | Trail.Frame.Continuation { fin; compressed; payload } ->
        (fin, compressed, payload)
    | Text { fin; compressed; payload } -> (fin, compressed, payload)
    | Binary { fin; compressed; payload } -> (fin, compressed, payload)
    | Connection_close { fin; compressed; payload } -> (fin, compressed, payload)
    | Ping -> (true, false, "")
    | Pong -> (true, false, "")
  in

  let frame_gen fn =
    QCheck.(tup3 bool bool string)
    |> QCheck.map ~rev:to_parts (fun (fin, compressed, payload) ->
           if mode = `request then
             fn ?fin:(Some fin) ?compressed:(Some compressed) payload
           else fn ?fin:None ?compressed:None payload)
  in
  QCheck.choose
    Trail.Frame.
      [
        frame_gen text;
        frame_gen binary;
        frame_gen connection_close;
        frame_gen continuation;
        QCheck.always Trail.Frame.ping;
        QCheck.always Trail.Frame.pong;
      ]

let proptest ?(count = 1_000_000) ~mode name fn =
  match
    let test = QCheck.Test.make ~count ~name (frame_gen ~mode) fn in
    QCheck.Test.check_exn test;
    Format.printf "prop %S OK\r\n%!" name
  with
  | exception exn ->
      let exn = Format.sprintf "Exception: %s" (Printexc.to_string exn) in
      Format.printf "\nTest %S failed with: \n\n%s" name exn;
      raise Fail
  | () -> ()

let () =
  Riot.run @@ fun () ->
  let _ = Logger.start () in
  Logger.set_log_level (Some Info);

  proptest "websocket_frame_request_serde" ~mode:`request request_serde;
  proptest "websocket_frame_response_serde" ~mode:`response response_serde
