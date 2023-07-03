defmodule Corsica.Telemetry do
  @moduledoc """
  Telemetry helpers and documentation around Corsica events.

  Corsica emits the following events:

    * `[:corsica, :accepted_request]` — when a CORS request is accepted.
    * `[:corsica, :invalid_request]` — when a request is not a CORS request.
    * `[:corsica, :rejected_request]` — when a CORS request is rejected. Includes the following
      extra metadata:
        * `:reason` — the reason why the request was rejected. Can be one of:
          * `:origin_not_allowed`
          * `{:req_method_not_allowed, req_method}`
          * `{:req_headers_not_allowed, non_allowed_headers}`

  **Metadata**: all the events include the following metadata in addition to any metadata
  explicitly specified in the list above.

    * `:request_type` — `:simple` or `:preflight`.
    * `:conn` - the `Plug.Conn` struct for the request.

  **Measurements**: none of the events include any measurements.

  ## Logging

  Corsica supports basic logging functionality through `attach_default_handler/0`.
  """
  @moduledoc since: "2.0.0"

  require Logger

  @default_log_levels %{rejected: :warning, invalid: :debug, accepted: :debug}

  @doc """
  Attaches a Telemetry handler for Corsica events that logs through `Logger`.

  This function exists to mimic the behavior of the `:log` option that existed in
  Corsica v1.x. It attaches a handler for the following events:

    * `[:corsica, :accepted_request]`
    * `[:corsica, :invalid_request]`
    * `[:corsica, :rejected_request]`

  The log levels can be customized through the `:log_levels` option that you can pass to
  this function. The levels and their defaults are:

    * `:accepted` — `:debug`
    * `:invalid` — `:debug`
    * `:rejected` — `:warning`

  The `:log_levels` option mirrors the `:log` option that you could pass to `Corsica` in
  v1.x.

  ## Usage

  We recommend calling this function in your application's `c:Application.start/2` callback.

  ## Examples

      def start(_type, _args) do
        children = [
          # ...
        ]

        Corsica.Telemetry.attach_default_handler(log_levels: [rejected: :error])

        Supervisor.start_link(children, strategy: :one_for_one)
      end

  """
  @doc since: "2.0.0"
  @spec attach_default_handler(keyword()) :: :ok
  def attach_default_handler(options \\ []) do
    levels =
      options
      |> Keyword.get(:log_levels, [])
      |> Map.new()

    levels = Map.merge(@default_log_levels, levels)

    events = [
      [:corsica, :accepted_request],
      [:corsica, :invalid_request],
      [:corsica, :rejected_request]
    ]

    :telemetry.attach_many(__MODULE__, events, &__MODULE__.handle_event/4, levels)
  end

  @doc false
  @spec handle_event(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          map()
        ) :: :ok
  def handle_event(
        [:corsica, type],
        _measurements,
        %{request_type: req_type, conn: conn} = meta,
        levels
      ) do
    cond do
      type == :accepted_request and req_type == :simple ->
        Logger.log(
          levels.accepted,
          ~s[Simple CORS request from Origin "#{Corsica.origin(conn)}" is allowed]
        )

      type == :accepted_request and req_type == :preflight ->
        Logger.log(
          levels.accepted,
          ~s[Preflight CORS request from Origin "#{Corsica.origin(conn)}" is allowed]
        )

      type == :invalid_request and req_type == :simple ->
        Logger.log(
          levels.invalid,
          ~s[Request is not a CORS request because there is no Origin header]
        )

      type == :invalid_request and req_type == :preflight ->
        Logger.log(levels.invalid, [
          "Request is not a preflight CORS request because either it has no Origin header, ",
          "its method is not OPTIONS, or it has no Access-Control-Request-Method header"
        ])

      type == :rejected_request and req_type == :simple ->
        Logger.log(
          levels.rejected,
          ~s[Simple CORS request from Origin "#{Corsica.origin(conn)}" is not allowed]
        )

      type == :rejected_request and req_type == :preflight ->
        case meta.reason do
          :origin_not_allowed ->
            Logger.log(levels.rejected, [
              "Preflight CORS request from Origin \"#{Corsica.origin(conn)}\" is not allowed ",
              "because its origin is not allowed"
            ])

          {:req_method_not_allowed, req_method} ->
            Logger.log(levels.rejected, [
              "Invalid preflight CORS request because the request ",
              "method (#{inspect(req_method)}) is not in :allow_methods"
            ])

          {:req_headers_not_allowed, non_allowed_headers} ->
            Logger.log(levels.rejected, [
              "Invalid preflight CORS request because these headers were ",
              "not allowed in :allow_headers: #{Enum.join(non_allowed_headers, ", ")}"
            ])
        end
    end

    :ok
  end
end
