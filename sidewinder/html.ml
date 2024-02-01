type 'msg attr = [ `event of string -> 'msg | `attr of string * string ]

let attr_id id = `attr ("id", id)
let attr_type typ = `attr ("type", typ)

type 'msg t =
  | El of { tag : string; attrs : 'msg attr list; children : 'msg t list }
  | Text of string
  | Splat of 'msg t list

let list els = Splat els

let button ~on_click ~children () =
  El { tag = "button"; attrs = [ on_click ]; children }

let html ~children () = El { tag = "html"; attrs = []; children }
let body ~children () = El { tag = "body"; attrs = []; children }

let div ?id ~children () =
  El
    {
      tag = "div";
      attrs = [ Option.map attr_id id ] |> List.filter_map Fun.id;
      children;
    }

let span ~children () = El { tag = "span"; attrs = []; children }

let script ?id ?type_ ~children () =
  El
    {
      tag = "script";
      attrs =
        [ Option.map attr_id id; Option.map attr_type type_ ]
        |> List.filter_map Fun.id;
      children;
    }

let event fn = `event fn
let string (str : string) = Text str
let int (x : int) = Text (Int.to_string x)

let rec to_string (t : 'msg t) =
  match t with
  | Text str -> str
  | Splat els -> String.concat "\n" (List.map to_string els)
  | El { tag; children; attrs } ->
      "<" ^ tag ^ " " ^ attrs_to_string attrs ^ ">"
      ^ (List.map to_string children |> String.concat "\n")
      ^ "</" ^ tag ^ ">"

and attrs_to_string attrs =
  List.map
    (function `attr (k, v) -> Format.sprintf "%s=%S" k v | _ -> "")
    attrs
  |> String.concat " "

let event_handlers attrs =
  List.filter_map
    (fun attr -> match attr with `event fn -> Some fn | _ -> None)
    attrs
