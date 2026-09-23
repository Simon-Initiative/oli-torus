defmodule OliWeb.SecureChannel do
  @moduledoc "Guard for channels without assessment-scoped dependency adapters."
  @doc false
  defmacro __using__(_) do
    quote do
      @before_compile OliWeb.SecureChannel
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    callbacks =
      for {name, arity} <- [join: 3, handle_in: 3, handle_info: 2],
          Module.defines?(env.module, {name, arity}),
          do: {name, arity}

    for {name, arity} <- callbacks do
      args = Macro.generate_arguments(arity, __MODULE__)
      socket = List.last(args)

      topic =
        case name do
          :join -> hd(args)
          _ -> quote(do: unquote(socket).topic)
        end

      failure =
        case name do
          :join -> quote(do: {:error, %{reason: "secure_resource_mismatch"}})
          _ -> quote(do: {:stop, :normal, unquote(socket)})
        end

      quote do
        defoverridable [{unquote(name), unquote(arity)}]

        def unquote(name)(unquote_splicing(args)) do
          case OliWeb.SecureSocket.channel_allowed?(unquote(socket), unquote(topic)) do
            true ->
              super(unquote_splicing(args))

            false ->
              :telemetry.execute([:oli, :secure_assessment, :denied], %{count: 1}, %{
                reason: :secure_resource_mismatch,
                transport: :channel
              })

              unquote(failure)
          end
        end
      end
    end
  end
end
