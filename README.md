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
Trail.[
  Logger.run;
  Request_id.run;
  Cqrs_token.run;
  Session.run;
  (fun conn req -> conn |> send_resp ~status:`OK ~body:"hello world!");
]
```

Trail also comes with support for [Riot][riot], and to start a Trail supervision tree you can call `Trail.start_link ~port trail ctx`.

[riot]: https://github.com/leostera/riot
[plug]: https://hexdocs.pm/plug/readme.html
