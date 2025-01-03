# Common Issues

This page contains a list of common issues that can be encountered when setting up CORS and Corsica. These issues are not necessarily specific to Corsica but they bubble up in the Corsica issue tracker often enough to justify talking about them in the documentation.

## Browser gives a *Origin ... is therefore not allowed access* error

When attempting to perform a CORS request to your server, your browser might log the following error in the console:

> Response to preflight request doesn't pass access control check: No 'Access-Control-Allow-Origin' header is present on the requested resource. Origin 'example.com' is therefore not allowed access.

This is a generic response that means your server is not allowing the CORS request. Some common reasons that can cause this are listed below.

  * **The Corsica plug is lower than any handling router in your plug pipeline (such as `Plug.Router`, a `Phoenix.Router`, or `Plug.Static`).** In order to be able to add CORS headers to responses and handle preflight requests, the Corsica plug (either with `plug Corsica` or as the router generated by `use Corsica.Router`) must be higher in the plug pipeline than plugs that send a response down the connection.

  * **The server doesn't recognize the origin (the browser's current URL) as an allowed origin.** Check the `:origins` option passed to Corsica. Make sure it allows whatever site the browser is trying perform the CORS request from. For example, if you are running a local JavaScript app on `http://localhost:8100`, then the `:origins` option must contain `http://localhost:8100` (or "\*" to allow anything). Read the documentation for the `Corsica` module for more information on the possible values of the `:origins` option.

  * **The server doesn't allow the headers that the client is requesting.** The client (such as the browser) can ask to use certain headers by sending a list of such headers in the `Access-Control-Request-Headers` header included in the preflight request. For example, the client could ask to use `Content-Type` and `Accept` by passing `Access-Control-Request-Headers: Content-Type, Accept`. The server (specifically, Corsica in this case) must respond to the preflight request and allow those headers by specifying them in the response `Access-Control-Allow-Headers` header.  You can use the `:allow_headers` option passed to Corsica. In the example above, you would have to pass something like `allow_headers: ["content-type", "accept"]`.
