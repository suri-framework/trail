open Riot

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

let make ~fin ~compressed ~rsv:_ ~opcode ~mask ~payload =
  let payload = unmask mask payload in

  match opcode with
  | 0x0 -> `ok (Continuation { fin; compressed; payload })
  | 0x1 -> `ok (Text { fin; compressed; payload })
  | 0x2 -> `ok (Binary { fin; compressed; payload })
  | 0x8 -> `ok (Connection_close { fin; compressed; payload })
  | 0x9 -> `ok Ping
  | 0xA -> `ok Pong
  | _ -> `error (`Unknown_opcode opcode)

let deserialize ?(max_frame_size = 0) data =
  let binstr = Bitstring.bitstring_of_string data in
  match%bitstring binstr with
  | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       pad1 : 1 : check( pad1 = true );
       pad2 : 7 : check( pad2 = 127 );
       length : 64;
       mask : 32;
       payload : Int64.(mul length 8L |> to_int) : string;
       rest : -1 : string |}
    when max_frame_size = 0 || Int64.(length <= of_int max_frame_size) ->
      Some (make ~fin ~compressed ~rsv ~opcode ~mask ~payload, rest)
  | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       pad1 : 1 : check( pad1 = true );
       pad2 : 7 : check( pad2 = 126 );
       length : 16 : int;
       mask : 32 : int;
       payload : (length * 8) : string;
       rest : -1 : string |}
    when max_frame_size = 0 || length <= max_frame_size ->
      Some (make ~fin ~compressed ~rsv ~opcode ~mask ~payload, rest)
  | {| fin : 1;
       compressed : 1;
       rsv : 2;
       opcode : 4;
       x : 1 : check( x = true );
       length : 7 : int;
       mask : 32 : int;
       payload : (length * 8) : string;
       rest : -1 : string |}
    when length <= 125 && (max_frame_size == 0 || length <= max_frame_size) ->
      Some (make ~fin ~compressed ~rsv ~opcode ~mask ~payload, rest)
  | {| data : -1 : string  |} -> Some (`more (IO.Buffer.of_string data), "")

let serialize (t : t) =
  let opcode, fin, compressed, payload =
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
  let%bitstring header = {| fin : 1; compressed : 1; 0x0 : 2; opcode : 4|} in
  let mask = function
    | () when bytes <= 125 -> {%bitstring| 0 : 1; (bytes) : 7 |}
    | () when bytes <= 65_535 -> {%bitstring| 0 : 1; 126 : 7; (bytes) : 16 |}
    | () -> {%bitstring| 0 : 1 ; 127 : 7; (Int64.of_int bytes) : 64 |}
  in
  let payload = Bitstring.bitstring_of_string payload in
  let data = Bitstring.concat [ header; mask (); payload ] in
  let frame = Bitstring.string_of_bitstring data in
  IO.Buffer.of_string frame
