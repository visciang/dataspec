# coveralls-ignore-start

if Code.ensure_loaded?(Plug) do
  defmodule DataSpecs.Plug.Cast do
    @moduledoc """
    DataSpecs Plug.

    NOTE: this module is available if you include the optional dependency `plug`.

    This module can be used to plug a "Jason.decode! -> DataSpecs.cast" pipeline in your routes.

    For example:

    ```elixir
    defmodule Api.Router.Something do
      use Plug.Router
      import #{inspect(__MODULE__)}, only: [typeref: 2, value: 1]

      plug :match
      plug #{inspect(__MODULE__)}
      plug :dispatch

      post "/foo", typeref(Api.Model.Foo, :t) do
        %Api.Model.Foo{...} = value(conn)
        ...
      end
    end

    defmodule Api.Model.Foo do
      defmodule Bar do
        @enforce_keys [:b1]
        defstruct @enforce_keys ++ [:b2]

        @type t :: %__MODULE__{
                b1: number(),
                b2: nil | String.t()
              }
      end

      @enforce_keys [:a, :bars]
      defstruct @enforce_keys

      @type t :: %__MODULE__{
              a: non_neg_integer(),
              bars: [Bar.t()]
            }
    end
    ```
    """

    use Plug.Builder
    alias DataSpecs.Types

    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:cast)

    @doc """
    Declare the type the body of a route should conform

    For example:

    ```elixir
    post "/foo", typeref(Model.Foo) do
      ...
    end
    ```
    """
    @spec typeref(module(), Types.type_id()) :: [assigns: %{dataspec: %{type: Types.mt(), value: term()}}]
    def typeref(module, type \\ :t), do: [assigns: %{dataspec: %{type: {module, type}, value: nil}}]

    @doc """
    Get the casted value.

    For example:

    ```elixir
    post "/foo", typeref(Api.Model.Foo, :t) do
      %Api.Model.Foo{...} = value(conn)
      ...
    end
    ```
    """
    @spec value(Plug.Conn.t()) :: term()
    def value(conn), do: conn.assigns.dataspec.value

    @spec cast(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
    defp cast(conn, _opts) do
      case get_typeref(conn) do
        {:ok, type_ref} ->
          case DataSpecs.cast(conn.body_params, type_ref) do
            {:ok, value} ->
              put_in(conn.assigns.dataspec.value, value)

            {:error, reason} ->
              conn
              |> resp(:bad_request, inspect(reason))
              |> halt()
          end

        :error ->
          raise_missing_typeref()
      end
    end

    @spec get_typeref(map()) :: {:ok, Types.mt()} | :error
    defp get_typeref(%{assigns: %{dataspec: %{type: type_ref}}}), do: {:ok, type_ref}
    defp get_typeref(_), do: :error

    @spec raise_missing_typeref :: no_return()
    defp raise_missing_typeref do
      raise """
      Probably you missed a typeref on this route.

        post "/foo", #{__MODULE__}.typeref(Foo, :t) do
          ...
        end
      """
    end
  end
end

# coveralls-ignore-stop
