open Riot

type t = {
  status : Http.Status.t;
  headers : Http.Header.t;
  version : Http.Version.t;
  body : IO.Buffer.t option;
}

let pp fmt ({ headers; version; status; _ } : t) =
  let res = Http.Response.make ~headers ~version ~status () in
  Http.Response.pp fmt res

let make status ?(headers = []) ?(version = `HTTP_1_1) ?body () =
  { status; version; headers = Http.Header.of_list headers; body }

let to_buffer { status; headers; version; body } =
  let version = version |> Http.Version.to_string |> Httpaf.Version.of_string in
  let status = status |> Http.Status.to_int |> Httpaf.Status.of_code in

  let headers =
    match body with
    | Some body ->
        let content_length =
          Http.Header.get headers "content-length"
          |> Option.value ~default:(IO.Buffer.length body |> Int.to_string)
        in
        Http.Header.add headers "content-length" content_length
    | None -> headers
  in

  let headers = headers |> Http.Header.to_list |> Httpaf.Headers.of_list in

  let res = Httpaf.Response.create ~version ~headers status in
  let buf = Faraday.create (1024 * 4) in
  Httpaf.Httpaf_private.Serialize.write_response buf res;

  (match body with
  | Some body ->
      let Cstruct.{ buffer = ba; len; off } = IO.Buffer.as_cstruct body in
      Faraday.write_bigstring buf ~off ~len ba;
      Faraday.write_string buf "\n\n0\n\n"
  | None -> ());

  let ba = Faraday.serialize_to_bigstring buf in
  let len = Bigstringaf.length ba in
  let cs = Cstruct.of_bigarray ~off:0 ~len ba in
  IO.Buffer.of_cstruct ~filled:len cs

type response =
  ?headers:(string * string) list ->
  ?version:Http.Version.t ->
  ?body:IO.Buffer.t ->
  unit ->
  t

let accepted = make `Accepted
let already_reported = make `Already_reported
let bad_gateway = make `Bad_gateway
let bad_request = make `Bad_request
let bandwidth_limit_exceeded = make `Bandwidth_limit_exceeded

let blocked_by_windows_parental_controls =
  make `Blocked_by_windows_parental_controls

let checkpoint = make `Checkpoint
let client_closed_request = make `Client_closed_request
let conflict = make `Conflict
let continue = make `Continue
let created = make `Created
let enhance_your_calm = make `Enhance_your_calm
let expectation_failed = make `Expectation_failed
let failed_dependency = make `Failed_dependency
let forbidden = make `Forbidden
let found = make `Found
let gateway_timeout = make `Gateway_timeout
let gone = make `Gone
let http_version_not_supported = make `Http_version_not_supported
let im_a_teapot = make `I_m_a_teapot
let im_used = make `Im_used
let insufficient_storage = make `Insufficient_storage
let internal_server_error = make `Internal_server_error
let length_required = make `Length_required
let locked = make `Locked
let loop_detected = make `Loop_detected
let method_not_allowed = make `Method_not_allowed
let moved_permanently = make `Moved_permanently
let multi_status = make `Multi_status
let multiple_choices = make `Multiple_choices
let network_authentication_required = make `Network_authentication_required
let network_connect_timeout_error = make `Network_connect_timeout_error
let network_read_timeout_error = make `Network_read_timeout_error
let no_content = make `No_content
let no_response = make `No_response
let non_authoritative_information = make `Non_authoritative_information
let not_acceptable = make `Not_acceptable
let not_extended = make `Not_extended
let not_found = make `Not_found
let not_implemented = make `Not_implemented
let not_modified = make `Not_modified
let ok = make `OK
let partial_content = make `Partial_content
let payment_required = make `Payment_required
let permanent_redirect = make `Permanent_redirect
let precondition_failed = make `Precondition_failed
let precondition_required = make `Precondition_required
let processing = make `Processing
let proxy_authentication_required = make `Proxy_authentication_required
let request_entity_too_large = make `Request_entity_too_large
let request_header_fields_too_large = make `Request_header_fields_too_large
let request_timeout = make `Request_timeout
let request_uri_too_long = make `Request_uri_too_long
let requested_range_not_satisfiable = make `Requested_range_not_satisfiable
let reset_content = make `Reset_content
let retry_with = make `Retry_with
let see_other = make `See_other
let service_unavailable = make `Service_unavailable
let switch_proxy = make `Switch_proxy
let switching_protocols = make `Switching_protocols
let temporary_redirect = make `Temporary_redirect
let too_many_requests = make `Too_many_requests
let unauthorized = make `Unauthorized
let unprocessable_entity = make `Unprocessable_entity
let unsupported_media_type = make `Unsupported_media_type
let upgrade_required = make `Upgrade_required
let use_proxy = make `Use_proxy
let variant_also_negotiates = make `Variant_also_negotiates
let wrong_exchange_server = make `Wrong_exchange_server
