open Riot
open Trail

open Riot.Logger.Make (struct
  let namespace = [ "sidewinder" ]
end)

module Html = Html

module Event = struct
  open Serde

  type t = string

  let serialize_t = Ser.(serializer @@ string)
  let deserialize_t = De.(deserializer @@ string)
end

type Message.t += Render of string

module type Intf = sig
  type state
  type action

  val mount : Conn.t -> state
  val handle_action : state -> action -> state
  val render : state:state -> unit -> action Html.t
end

module Default = Sidewinder_default

module Component = struct
  type ('state, 'action) t = {
    ref : 'action Ref.t;
    state : 'state;
    handle_action : 'state -> 'action -> 'state;
    render : state:'state -> unit -> 'action Html.t;
    handlers : (string, Event.t -> 'action) Hashtbl.t;
    renderer : Pid.t;
  }

  type Message.t +=
    | Mount
    | Event of { id : string; event : Event.t }
    | Dispatch : 'action Ref.t * 'action -> Message.t

  let render t html =
    let str = Html.to_string html in
    send t.renderer (Render str)

  let rec update_handlers ?(idx = 0) t (html : 'action Html.t) =
    match html with
    | Html.Text _ -> html
    | Html.Splat els ->
        Html.Splat (List.mapi (fun idx el -> update_handlers ~idx t el) els)
    | Html.El { tag; attrs; children } ->
        trace (fun f -> f "found tag %S with %d attrs" tag (List.length attrs));
        let attrs =
          match Html.event_handlers attrs with
          | [] -> attrs
          | handlers ->
              let attrs = ref attrs in
              List.iteri
                (fun n (name, handler) ->
                  let id =
                    "sidewinder-handler-" ^ Int.to_string idx ^ "-"
                    ^ Int.to_string n
                  in
                  trace (fun f -> f "found handler %S" id);
                  Hashtbl.replace t.handlers id handler;
                  attrs :=
                    Html.
                      [
                        attr "data-sw-event" name; attr "data-sidewinder-id" id;
                      ]
                    @ !attrs;
                  ())
                handlers;
              !attrs
        in
        let children = List.mapi (fun idx -> update_handlers ~idx t) children in
        Html.El { tag; attrs; children }

  let rec loop (t : ('state', 'action) t) =
    match receive () with
    | Mount -> handle_mount t
    | Event { id; event } -> handle_event t id event
    | Dispatch (ref, action) -> (
        match Ref.cast ref t.ref action with
        | Some action -> handle_action t action
        | None -> failwith "bad message")
    | _ -> loop t

  and handle_action t action =
    trace (fun f -> f "%a is handling action" Pid.pp (self ()));
    let state = t.handle_action t.state action in
    let html = t.render ~state () in
    let html = update_handlers t html in
    render t html;
    loop { t with state }

  and handle_event t id event =
    trace (fun f -> f "%a is handling event" Pid.pp (self ()));
    match Hashtbl.find_opt t.handlers id with
    | None -> loop t
    | Some handler ->
        let action = handler event in
        send (self ()) (Dispatch (t.ref, action));
        loop t

  and handle_mount t =
    trace (fun f -> f "%a is mounting" Pid.pp (self ()));
    let html = t.render ~state:t.state () in
    let html = update_handlers t html in
    render t html;
    loop t

  let start_link renderer (module C : Intf) =
    let pid =
      spawn_link (fun () ->
          loop
            {
              ref = Ref.make ();
              renderer;
              state = C.mount (Obj.magic 2112);
              handle_action = C.handle_action;
              render = C.render;
              handlers = Hashtbl.create 0;
            })
    in
    Ok pid

  let mount pid = send pid Mount
  let event pid id event = send pid (Event { id; event })
end

type event = Mount | Event of string * Event.t | Patch of string
[@@deriving deserialize, serialize]

module Mount (C : Intf) = struct
  include Sock.Default

  type args = unit
  type state = { component : Pid.t }

  let init () =
    let this = self () in
    let component = Component.start_link this (module C) |> Result.get_ok in
    `ok { component }

  let handle_frame (frame : Frame.t) _conn state =
    match frame with
    | Frame.Text { payload; _ } -> (
        trace (fun f -> f "got event: %S" payload);
        match Serde_json.of_string deserialize_event payload with
        | Ok (Event (id, event)) ->
            Component.event state.component id event;
            `ok state
        | Ok Mount ->
            Component.mount state.component;
            `ok state
        | Ok _ -> `ok state
        | Error err ->
            error (fun f ->
                f "could not deserialize frame: %S" (Marshal.to_string err []));
            `ok state)
    | Frame.Ping -> `push ([ Frame.pong ], state)
    | _ -> `ok state

  let handle_message msg state =
    trace (fun f -> f "handle_message");
    match msg with
    | Render html ->
        let event =
          Serde_json.to_string serialize_event (Patch html)
          |> Result.get_ok
        in
        let frame = Frame.text ~fin:true event in
        `push ([ frame ], state)
    | _ -> `ok state
end

let live path (module C : Intf) = Trail.Router.socket path (module Mount (C)) ()

module Static = struct
  open Riot
  open Trail

  open Riot.Logger.Make (struct
    let namespace = [ "sidewinder"; "static" ]
  end)

  type args = unit
  type state = unit

  let init () = ()

  let call (conn : Conn.t) () =
    let rel_path = conn.req.path |> String.concat Stdlib.Filename.dir_sep in
    debug (fun f -> f "testing file at %S" rel_path);
    if String.starts_with ~prefix:"@sidewinder_static/" rel_path then
      let path =
        Stringext.replace_all ~pattern:"@sidewinder_static/" ~with_:"" rel_path
      in
      match Sidewinder_js.read path with
      | Some file ->
          let data = Bytestring.of_string file in
          let mime_type = Magic_mime.lookup path in
          conn
          |> Conn.with_header "content-type" mime_type
          |> Conn.send_response `OK data
      | None -> conn |> Conn.send_response `Not_found {%b||}
    else conn
end
