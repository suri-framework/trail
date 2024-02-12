open Riot

open Logger.Make (struct
  let namespace = [ "trail"; "ws"; "frame" ]
end)

(**
    0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-------+-+-------------+-------------------------------+
    |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
    |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
    |N|V|V|V|       |S|             |   (if payload len==126/127)   |
    | |1|2|3|       |K|             |                               |
    +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
    |     Extended payload length continued, if payload len == 127  |
    + - - - - - - - - - - - - - - - +-------------------------------+
    |                               |Masking-key, if MASK set to 1  |
    +-------------------------------+-------------------------------+
    | Masking-key (continued)       |          Payload Data         |
    +-------------------------------- - - - - - - - - - - - - - - - +
    :                     Payload Data continued ...                :
    + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
    |                     Payload Data continued ...                |
    +---------------------------------------------------------------+

    from: https://datatracker.ietf.org/doc/html/rfc6455#section-5.2
*)

type t =
  | Continuation of { fin : bool; compressed : bool; payload : string }
  | Text of { fin : bool; compressed : bool; payload : string }
  | Binary of { fin : bool; compressed : bool; payload : string }
  | Connection_close of { fin : bool; compressed : bool; payload : string }
  | Ping
  | Pong

let equal (a : t) (b : t) =
  match (a, b) with
  | ( Continuation { fin = fin1; compressed = compressed1; payload = payload1 },
      Continuation { fin = fin2; compressed = compressed2; payload = payload2 }
    ) ->
      fin1 = fin2 && compressed1 = compressed2 && String.equal payload1 payload2
  | ( Text { fin = fin1; compressed = compressed1; payload = payload1 },
      Text { fin = fin2; compressed = compressed2; payload = payload2 } ) ->
      fin1 = fin2 && compressed1 = compressed2 && String.equal payload1 payload2
  | ( Binary { fin = fin1; compressed = compressed1; payload = payload1 },
      Binary { fin = fin2; compressed = compressed2; payload = payload2 } ) ->
      fin1 = fin2 && compressed1 = compressed2 && String.equal payload1 payload2
  | ( Connection_close
        { fin = fin1; compressed = compressed1; payload = payload1 },
      Connection_close
        { fin = fin2; compressed = compressed2; payload = payload2 } ) ->
      fin1 = fin2 && compressed1 = compressed2 && String.equal payload1 payload2
  | Ping, Ping | Pong, Pong -> true
  | _ -> false

let text ?(fin = false) ?(compressed = false) payload =
  Text { fin; compressed; payload }

let binary ?(fin = false) ?(compressed = false) payload =
  Binary { fin; compressed; payload }

let continuation ?(fin = false) ?(compressed = false) payload =
  Continuation { fin; compressed; payload }

let connection_close ?(fin = false) ?(compressed = false) payload =
  Connection_close { fin; compressed; payload }

let ping = Ping
let pong = Pong

let pp fmt (t : t) =
  match t with
  | Continuation { fin; compressed; payload } ->
      Format.fprintf fmt "frame.continuation(%b,%b,%S)" fin compressed payload
  | Text { fin; compressed; payload } ->
      Format.fprintf fmt "frame.text(%b,%b,%S)" fin compressed payload
  | Binary { fin; compressed; payload } ->
      Format.fprintf fmt "frame.binary(%b,%b,%S)" fin compressed payload
  | Connection_close { fin; compressed; payload } ->
      Format.fprintf fmt "frame.connection_close(%b,%b,%S)" fin compressed
        payload
  | Ping -> Format.fprintf fmt "frame.ping"
  | Pong -> Format.fprintf fmt "frame.pong"

(* this function was copied from https://github.com/anmonteiro/websocketaf/blob/fork/lib/websocket.ml#L170-L176 *)
let unmask mask payload =
  let len = String.length payload in
  let bs = Bigstringaf.of_string ~off:0 ~len payload in
  for i = 0 to len - 1 do
    let j = i mod 4 in
    let c = Bigstringaf.unsafe_get bs i |> Char.code in
    let c =
      c lxor Int32.(logand (shift_right mask (8 * (3 - j))) 0xffl |> to_int)
    in
    Bigstringaf.unsafe_set bs i (Char.unsafe_chr c)
  done;
  Bigstringaf.to_string bs

let new_mask () = Crypto.Random.int32 ()

let make ~masked ~fin ~compressed ~rsv:_ ~opcode ~mask ~payload =
  let payload = if masked then unmask mask payload else payload in

  match opcode with
  | 0x0 -> `ok (Continuation { fin; compressed; payload })
  | 0x1 -> `ok (Text { fin; compressed; payload })
  | 0x2 -> `ok (Binary { fin; compressed; payload })
  | 0x8 -> `ok (Connection_close { fin; compressed; payload })
  | 0x9 -> `ok Ping
  | 0xA -> `ok Pong
  | _ -> `error (`Unknown_opcode opcode)

module Request = struct
  let deserialize ?(max_frame_size = 0) data =
    let binstr = Bitstring.bitstring_of_string data in
    match%bitstring binstr with
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check( masked = true );
       pad2 : 7 : check( pad2 = 127 );
       length : 64;
       mask : 32;
       payload : Int64.(mul length 8L |> to_int) : string;
       rest : -1 : bitstring |}
      when max_frame_size = 0 || Int64.(length <= of_int max_frame_size) ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check( masked = true );
       pad2 : 7 : check( pad2 = 126 );
       length : 16 : int;
       mask : 32 : int;
       payload : (length * 8) : string;
       rest : -1 : bitstring |}
      when max_frame_size = 0 || length <= max_frame_size ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check( masked = true );
       length : 7 : int;
       mask : 32 : int;
       payload : (length * 8) : string;
       rest : -1 : bitstring |}
      when length <= 125 && (max_frame_size == 0 || length <= max_frame_size) ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask ~payload,
            Bitstring.string_of_bitstring rest )
    | {| _data : -1 : bitstring  |} ->
        Some (`more (Bytestring.of_string data), "")

  let serialize (t : t) =
    let opcode, fin, compressed, mask, payload =
      match t with
      | Continuation { fin; compressed; payload } ->
          (0x0, fin, compressed, new_mask (), payload)
      | Text { fin; compressed; payload } ->
          (0x1, fin, compressed, new_mask (), payload)
      | Binary { fin; compressed; payload } ->
          (0x2, fin, compressed, new_mask (), payload)
      | Connection_close { fin; compressed; payload } ->
          (0x8, fin, compressed, new_mask (), payload)
      | Ping -> (0x9, true, false, new_mask (), "")
      | Pong -> (0xA, true, false, new_mask (), "")
    in
    let bytes = String.to_bytes payload |> Bytes.length in

    let encoded_payload_length = function
      | () when bytes <= 125 -> {%bitstring| (bytes) : 7 ; (mask) : 32 |}
      | () when bytes <= 65_535 ->
          {%bitstring| 126 : 7; (bytes) : 16 ; (mask) : 32 |}
      | () -> {%bitstring| 127 : 7; (Int64.of_int bytes) : 64 ; (mask) : 32 |}
    in
    let%bitstring header =
      {| fin : 1; compressed : 1 ; 0x0 : 2; opcode : 4 ; 1 : 1 |}
    in

    let payload = unmask mask payload in
    let payload = Bitstring.bitstring_of_string payload in

    let data =
      Bitstring.concat [ header; encoded_payload_length (); payload ]
    in

    let frame = Bitstring.string_of_bitstring data in
    let bytestring = Bytestring.of_string frame in
    bytestring
end

module Response = struct
  let deserialize data =
    let binstr = Bitstring.bitstring_of_string data in
    match%bitstring binstr with
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check (masked = true);
       pad2 : 7 : check( pad2 = 127 );
       length : 64;
       mask : 32;
       payload : Int64.(mul length 8L |> to_int) : string;
       rest : -1 : bitstring |}
      ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check (masked = false);
       pad2 : 7 : check( pad2 = 127 );
       length : 64;
       payload : Int64.(mul length 8L |> to_int) : string;
       rest : -1 : bitstring |}
      ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask:0l ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check (masked = true);
       pad2 : 7 : check( pad2 = 126 );
       length : 16 : int;
       mask : 32 : int;
       payload : (length * 8) : string;
       rest : -1 : bitstring |}
      ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check (masked = false);
       pad2 : 7 : check( pad2 = 126 );
       length : 16 : int;
       payload : (length * 8) : string;
       rest : -1 : bitstring |}
      ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask:0l ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check (masked = true);
       length : 7 : int;
       mask : 32 : int;
       payload : (length * 8) : string;
       rest : -1 : bitstring |}
      when length >= 0 && length <= 125 ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask ~payload,
            Bitstring.string_of_bitstring rest )
    | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       masked : 1 : check (masked = false);
       length : 7 : int;
       payload : (length * 8) : string;
       rest : -1 : bitstring |}
      when length >= 0 && length <= 125 ->
        Some
          ( make ~masked ~fin ~compressed ~rsv ~opcode ~mask:0l ~payload,
            Bitstring.string_of_bitstring rest )
    | {| _data : -1 : bitstring  |} ->
        Some (`more (Bytestring.of_string data), "")

  let serialize (t : t) =
    let compressed = false in
    let opcode, fin, _compressed, payload =
      match t with
      | Continuation { fin; compressed; payload } ->
          (0x0, fin, compressed, payload)
      | Text { fin; compressed; payload } -> (0x1, fin, compressed, payload)
      | Binary { fin; compressed; payload } -> (0x2, fin, compressed, payload)
      | Connection_close { fin; compressed; payload } ->
          (0x8, fin, compressed, payload)
      | Ping -> (0x9, true, false, "")
      | Pong -> (0xA, true, false, "")
    in
    let bytes = String.to_bytes payload |> Bytes.length in
    trace (fun f -> f "payload has %d bytes" bytes);
    let%bitstring header = {| fin : 1; compressed : 1; 0x0 : 2; opcode : 4|} in
    let mask = function
      | () when bytes <= 125 -> {%bitstring| 0 : 1; (bytes) : 7 |}
      | () when bytes <= 65_535 -> {%bitstring| 0 : 1; 126 : 7; (bytes) : 16|}
      | () -> {%bitstring| 0 : 1 ; 127 : 7; (Int64.of_int bytes) : 64 |}
    in
    let payload = Bitstring.bitstring_of_string payload in
    let data = Bitstring.concat [ header; mask (); payload ] in
    let frame = Bitstring.string_of_bitstring data in
    let bytestring = Bytestring.of_string frame in
    bytestring
end
