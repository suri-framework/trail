module Event = struct
  type t

  external data : t -> string = "data" [@@mel.get]
  external parse : string -> 'a = "JSON.parse"
  external getAttribute : t -> string -> string = "getAttribute" [@@mel.send]
end

module WebSocket = struct
  type t

  external make : string -> t = "WebSocket" [@@mel.new]
  external send : t -> string -> unit = "send" [@@mel.send]

  external addEventListener : t -> string -> (Event.t -> unit) -> unit
    = "addEventListener"
  [@@mel.send]
end

module Element = struct
  type t

  external innerHTML : t -> string -> unit = "innerHTML" [@@mel.set]

  external addEventListener : t -> string -> (Event.t -> unit) -> unit
    = "addEventListener"
  [@@mel.send]
end

module Document = struct
  type t

  external document : t = "document"

  external getElementById : t -> string -> Element.t = "getElementById"
  [@@mel.send]
end

type event = Patch of string

let mount socket _event =
  let data = {| "Mount" |} in
  WebSocket.send socket data

let event =
  {%raw| function (element, event) {
  let id = element.getAttribute("data-sidewinder-id");
  return JSON.stringify({ "Event": [id, ""] })
} |}

let handle_click socket el e = WebSocket.send socket (event el e)

let rebind =
  {%raw| function (socket, element) { 
  let elements = [...element.querySelectorAll("*[data-sidewinder-id]")];
  elements.forEach((el) => {
    el.addEventListener("click", (ev) => handle_click(socket, el, ev));
  });
} |}

let patch =
  {%raw|
function (event) {
let json = JSON.parse(event.data);
return json.Patch[0]
}
|}

let handle_event socket element e =
  let diff = patch e in
  Element.innerHTML element diff;
  rebind socket element

let url : string -> string =
  {%raw| function (path) {
  let protocol = window.location.protocol.replace("http", "ws");
  return `${protocol}//${window.location.host}${path}`
} |}

let spawnRemote url element_id =
  let element = Document.(getElementById document element_id) in
  let socket = WebSocket.make url in
  WebSocket.addEventListener socket "open" @@ mount socket;
  WebSocket.addEventListener socket "message" @@ handle_event socket element

let spawn element_id path =
  let url = url path in
  spawnRemote url element_id
