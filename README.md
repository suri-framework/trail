# Trail 

Trail is a minimalistic, composable framework for building HTTP/WebSocket
servers, inspired by [Plug][plug] & [WebSock][websock]. It provides its users
with a small set of abstractions for building _trails_ that can be assembled to
handle a request.

To create a Trail, you can use the syntax `Trail.[fn1;fn2;fn3;...]`, where each
function takes a connection object and an arbitrary context, to produce a new
connection object.

For example:

```ocaml
open Trail
open Router

let endpoint =
  [
    use (module Logger) Logger.(args ~level:Debug ());
    router
      [
        socket "/ws" (module My_handler) ();
        get "/" (fun conn -> Conn.send_response `OK {%b|"hello world"|} conn);
        scope "/api"
          [
            get "/version" (fun conn ->
                Conn.send_response `OK {%b|"none"|} conn);
          ];
      ];
  ]
```

[riot]: https://github.com/leostera/riot
[plug]: https://hexdocs.pm/plug/readme.html
