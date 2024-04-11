# 0.0.1

Initial release of Trail, including:

* a simple interface for defining servers as functions over a Connection object
  to handle incoming requests and response

* a `use` function to insert new middlewares in the connection pipeline

* a `router` function to define scoped routes using different http verbs
  * support for `delete`, `get`, `head`, `patch`, `post`, `put` http verbs
  * support for `resource` which expects a module implementing common REST operations (create, read, update, delete, etc)
  * support for `socket` routes that automatically upgrade connections to WebSockets

* a module interface for defining socket handlers

* a simple hello world example with routes, middlewares, and sockets

* a few common middlewares:
  * a CORS middleware to facilitate setting up CORS in servers
  * a `Request_id` middleware to assign a unique id header to every request
  * a `Logger` middleware that logs requests with several measurements
  * a `Static` middleware to server static files from the file system
