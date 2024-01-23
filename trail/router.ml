open Riot
module Conn = Connection

open Logger.Make (struct
  let namespace = [ "trail"; "router" ]
end)

module type Resource = sig
  val create : Conn.t -> Conn.t
  val delete : Conn.t -> Conn.t
  val edit : Conn.t -> Conn.t
  val get : Conn.t -> Conn.t
  val index : Conn.t -> Conn.t
  val new_ : Conn.t -> Conn.t
  val update : Conn.t -> Conn.t
end

type t =
  | Scope of { name : string; routes : t list }
  | Route of { meth : Http.Method.t; path : string; handler : Pipeline.trail }

let rec pp fmt (t : t) =
  match t with
  | Scope { name; routes } ->
      Format.fprintf fmt "scope %S [" name;
      Format.pp_print_list
        ~pp_sep:(fun fmt () -> Format.fprintf fmt ";\n")
        pp fmt routes;
      Format.fprintf fmt "]"
  | Route { meth; path; _ } ->
      Format.fprintf fmt "%s %S" (Http.Method.to_string meth) path

let remove_trailing_slash s =
  let s =
    if String.starts_with ~prefix:"/" s then String.sub s 1 (String.length s - 1)
    else s
  in
  let s =
    if String.ends_with ~suffix:"/" s then String.sub s 0 (String.length s - 2)
    else s
  in
  if String.equal s "" then "/" else s

let scope name routes = Scope { name = remove_trailing_slash name; routes }

let route meth path handler =
  Route { meth; path = remove_trailing_slash path; handler }

let delete path handler = route `DELETE path handler
let get path handler = route `GET path handler
let head path handler = route `HEAD path handler
let patch path handler = route `PATCH path handler
let post path handler = route `POST path handler
let put path handler = route `PUT path handler

let resource name (module R : Resource) =
  scope name
    [
      get "/" R.index;
      get "/:id" R.get;
      get "/:id/edit" R.edit;
      get "/new" R.new_;
      post "/" R.create;
      patch "/:id" R.update;
      put "/:id" R.update;
      delete "/:id" R.delete;
    ]

module Matcher = struct
  type t =
    | Root
    | Part of string
    | Var of string
    | End of Http.Method.t * Pipeline.trail

  let pp_one fmt (t : t) =
    match t with
    | Root -> Format.fprintf fmt "Root"
    | Part p -> Format.fprintf fmt "Part %S" p
    | Var v -> Format.fprintf fmt "Var %S" v
    | End (m, _) -> Format.fprintf fmt "End %a" Http.Method.pp m

  let pp fmt (t : t list) =
    Format.fprintf fmt "[";
    Format.pp_print_list
      ~pp_sep:(fun fmt () -> Format.fprintf fmt "; ")
      pp_one fmt t;
    Format.fprintf fmt "]"

  let of_path path meth fn =
    (String.split_on_char '/' path
    |> List.map (fun part ->
           match part with
           | "" -> Root
           | part when String.starts_with ~prefix:":" part ->
               Var (String.sub part 1 (String.length part - 1))
           | part -> Part part))
    @ [ End (meth, fn) ]

  let rec of_router router : t list list =
    match router with
    | Scope { name; routes } ->
        let prefix = [ Root; Part name ] in
        List.concat_map
          (fun r -> List.map (fun r -> prefix @ r) (of_router r))
          routes
    | Route { meth; path; handler } -> [ of_path path meth handler ]

  let rec equal a b =
    match (a, b) with
    | End (m1, _h1) :: [], End (m2, _) :: [] when Http.Method.compare m1 m2 = 0
      ->
        true
    | Root :: t1, Root :: t2 -> equal t1 t2
    | Part p1 :: t1, Part p2 :: t2 when String.equal p1 p2 -> equal t1 t2
    | Var v1 :: t1, Var v2 :: t2 when String.equal v1 v2 -> equal t1 t2
    | _ -> false

  let rec compress_once (matcher : t list) =
    match matcher with
    | [] -> []
    | Part "/" :: rest -> Root :: compress_once rest
    | Root :: Root :: rest -> Root :: compress_once rest
    | Root :: Part "/" :: rest -> Root :: compress_once rest
    | Part p :: Root :: rest -> Part p :: compress_once rest
    | part :: rest -> part :: compress_once rest

  let rec compress (matcher : t list) =
    let matcher' = compress_once matcher in
    if equal matcher matcher' then matcher' else compress matcher'

  let of_router r = List.map compress (of_router r)
  let of_path p m = compress (of_path p m (fun conn -> conn))

  let rec try_match a b captures =
    match (a, b) with
    | End (m1, h1) :: [], End (m2, _) :: [] when Http.Method.compare m1 m2 = 0
      ->
        Some (h1, captures)
    | Root :: t1, Root :: t2 -> try_match t1 t2 captures
    | Part p1 :: t1, Part p2 :: t2 when String.equal p1 p2 ->
        try_match t1 t2 captures
    | Var v :: t1, Part p :: t2 ->
        let captures = (v, p) :: captures in
        try_match t1 t2 captures
    | _ -> None

  let try_match (matchers : t list list) (pattern : t list) =
    List.nth_opt
      (List.filter_map
         (fun (matcher : t list) -> try_match matcher pattern [])
         matchers)
      0
end

let make (t : t) (conn : Conn.t) =
  let req_path = Matcher.of_path conn.path conn.meth in
  trace (fun f -> f "req: %a" Matcher.pp req_path);
  let matcher = Matcher.of_router t in
  List.iter
    (fun matcher -> trace (fun f -> f "matcher: %a" Matcher.pp matcher))
    matcher;
  match Matcher.try_match matcher req_path with
  | None -> conn |> Conn.send_response `Not_found {%b||}
  | Some (handler, params) -> conn |> Conn.set_params params |> handler

let router t conn = make (scope "/" t) conn
