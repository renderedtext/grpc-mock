defmodule GrpcMock do
  @moduledoc """
  GrpcMock is library for easy gRPC server mocking to be used with
  [grpc-elixir library](https://github.com/tony612/grpc-elixir).

  ### Concurrency
  Unlike `mox`, GrpcMock is not thread-safe and cannot be used in concurrent tests.

  ## Example

  As an example, imagine that your application is using a remote calculator,
  with API defined in .proto file like this:

      service Calculator {
        rpc Add(AddRequest) returns (AddResponse);
        rpc Mult(MultRequest) returns (MultResponse);
      }

  If you want to mock the calculator gRPC calls during tests, the first step
  is to define the mock, usually in your `test_helper.exs`:

      GrpcMock.defmock(CalcMock, for: Calculator)

  Now in your tests, you can define expectations and verify them:

      use ExUnit.Case

      test "invokes add and mult" do
        # Start the gRPC server
        Server.start(CalcMock, 50_051)

        # Connect to the serrver
        {:ok, channel} = GRPC.Stub.connect("localhost:50051")

        CalcMock
        |> GrpcMock.expect(:add, fn req, _ -> AddResponse.new(sum: req.x + req.y) end)
        |> GrpcMock.expect(:mult, fn req, _ -> AddResponse.new(sum: req.x * req.y) end)

        request = AddRequest.new(x: 2, y: 3)
        assert {:ok, reply} = channel |> Stub.add(request)
        assert reply.sum == 5

        request = MultRequest.new(x: 2, y: 3)
        assert {:ok, reply} = channel |> Stub.mult(request)
        assert reply.sum == 6

        GrpcMock.verify!(CalcMock)
      end
  """

  alias GrpcMock.Server

  defmodule UnexpectedCallError do
    defexception [:message]
  end

  defmodule VerificationError do
    defexception [:message]
  end

  @doc """
  Define mock in runtime based on specificatin on pb.ex file

  ## Example

      GrpcMock.defmock(CalcMock, for: Calculator)
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

  @doc """
  Expect the `name` operation to be called `n` times.

  ## Examples
  To expect `add` to be called five times:

      expect(MyMock, :add, 5, fn request, stream -> ... end)

  `expect/4` can be invoked multiple times for the same `name`,
  allowing different behaviours on each invocation.
  """
  def expect(mock, name, n \\ 1, code) do
    calls = List.duplicate(code, n)
    :ok = Server.add_expectation(mock, name, {n, calls, nil})

    mock
  end

  @doc """
  There can be only one stubbed function.
  Number of expected invocations is not defined.

  If third argument is function, it is invoked as body of the stubbed function.

  ## Example

      stub(CalcMock, :add, fn(request, _) -> ... end)

  If third argument is anything other ten a function,
  it will be used as stub return value.

  ## Example

      stub(CalcMock, :add, AddResponse.new(sum: 12) end)
  """
  def stub(mock, name, code) when is_function(code) do
    Server.add_expectation(mock, name, {0, [], code})
  end

  def stub(mock, name, resp) do
    code = fn _request, _stream -> resp end

    stub(mock, name, code)
  end

  @doc """
  Verify that all operations for the specified mock are called expected number of times
  and remove all expectations for it.
  """
  def verify!(mock) do
    pending = Server.verify(mock)

    messages =
      for {fname, total, remaining} <- pending do
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

  defp camel2snake(atom) do
    atom |> Atom.to_string() |> Macro.underscore() |> String.to_atom()
  end

  def __dispatch__(mock, fname, args) do
    mock
    |> Server.fetch_fun(fname)
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
