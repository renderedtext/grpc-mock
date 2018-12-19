defmodule GrpcMock do
  @moduledoc """
  Documentation for GrpcMock.
  """

  alias GrpcMock.Server

  defmodule UnexpectedCallError do
      defexception [:message]
  end

  defmodule VerificationError do
      defexception [:message]
  end

  @doc """
  """
  def defmock(name, options) do
    service =
      case Keyword.fetch(options, :for) do
        {:ok, svc} -> svc
        :error -> raise ArgumentError, ":for option is required on defmock"
      end

    body =
      service.__rpc_calls__()
      |> generate_mocked_funs(name)

    Module.create(name, [header(service) | body], Macro.Env.location(__ENV__))
  end

  defp generate_mocked_funs(rpc_calls, name) do
    for {fname_camel_atom, _, _} <- rpc_calls do
      fname_snake = camel2snake(fname_camel_atom)

      quote do
        def unquote(fname_snake)(request, stream) do
          GrpcMock.__dispatch__(unquote(name), unquote(fname_snake), [request, stream])
        end
      end

    end
  end

  def expect(mock, name, n \\ 1, code) do
    calls = List.duplicate(code, n)
    :ok = Server.add_expectation(mock, name, {n, calls, nil})

    mock
  end

  def stub(mock, name, code) when is_function(code) do do
    Server.add_expectation(mock, name, {0, [], code})
  end

  def stub(mock, name, resp) do
    code = fn(_request, _stream) -> resp end

    stub(mock, name, code)
  end

  def verify!(mock) do
    pending = Server.verify(mock)

    messages = for {fname, total, remaining} <- pending do
      mfa = Exception.format_mfa(mock, fname, 2)
      called = total - remaining
      "  * expected #{mfa} to be invoked #{times(total)} but it was invoked #{times(called)}"
    end

    if messages != [] do
      raise VerificationError,
            "error while verifying calls for mock #{mock}:\n\n" <> Enum.join(messages, "\n")
    end

    :ok
  end

  defp header(service) do
    quote do
      use GRPC.Server, service: unquote(service)
    end
  end

  def camel2snake(atom) do
    atom |> Atom.to_string() |> Macro.underscore() |> String.to_atom()
  end

  def __dispatch__(mock, fname, args) do
    Server.fetch_fun(mock, fname)
    |> case do
      :no_expectation ->
        mfa = Exception.format_mfa(mock, fname, args)

        raise UnexpectedCallError,
              "no expectation defined for #{mfa}"

      {:out_of_expectations, count} ->
        mfa = Exception.format_mfa(mock, fname, args)

        raise UnexpectedCallError,
              "expected #{mfa} to be called #{times(count)} but it has been " <>
                "called #{times(count + 1)}"

      {:ok, fun_to_call} ->
        apply(fun_to_call, args)
    end
  end

  defp times(1), do: "once"
  defp times(n), do: "#{n} times"
end
