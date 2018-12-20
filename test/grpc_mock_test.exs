defmodule GrpcMockTest do
  use ExUnit.Case
  doctest GrpcMock

  alias GRPC.Server
  alias Calculator.Stub
  alias AddResponse
  alias AddRequest

  import GrpcMock

  @mock CalcMock

  setup_all do
    Server.start(@mock, 50_051)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    {:ok, %{channel: channel}}
  end

  test "use stub - struct", %{channel: channel} do
    sum = 12
    @mock
    |> stub(:add, AddResponse.new(sum: 12))

    request = AddRequest.new()
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == sum

    GrpcMock.verify!(@mock)
  end

  test "use stub - func", %{channel: channel} do
    x = 13

    @mock
    |> stub(:add, fn req, _ -> AddResponse.new(sum: req.x) end)

    request = AddRequest.new(x: x)
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == x

    GrpcMock.verify!(@mock)
  end

  test "expect - multiple operations", %{channel: channel} do
    x = 2
    y = 3
    sum = x + y
    prod = x * y

    @mock
    |> expect(:add, fn req, _ -> AddResponse.new(sum: req.x + req.y) end)
    |> expect(:mult, fn req, _ -> AddResponse.new(sum: req.x * req.y) end)

    request = AddRequest.new(x: x, y: y)
    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == sum

    request = MultRequest.new(x: x, y: y)
    assert {:ok, reply} = channel |> Stub.mult(request)
    assert reply.prod == prod

    GrpcMock.verify!(@mock)
  end

  test "expect - one invocation", %{channel: channel} do
    x = 5

    @mock
    |> expect(:add, fn req, _ -> AddResponse.new(sum: req.x) end)

    request = AddRequest.new(x: x)
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == x

    GrpcMock.verify!(@mock)
  end

  test "expect - 3 invocations", %{channel: channel} do
    x = 9
    sum = 42

    @mock
    |> expect(:add, fn req, _ -> AddResponse.new(sum: req.x) end)
    |> expect(:add, 2, fn _, _ -> AddResponse.new(sum: sum) end)

    request = AddRequest.new(x: x)
    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == x

    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == sum

    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == sum

    GrpcMock.verify!(@mock)
  end

  test "expect - fail" do
    @mock
    |> expect(:add, fn req, _ -> AddResponse.new(sum: req.x) end)

    assert_raise(
      GrpcMock.VerificationError,
      ~r/CalcMock.add.*invoked 0 times/,
      fn -> GrpcMock.verify!(@mock) end
    )
  end
end
