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

  test "stub - struct", %{channel: channel} do
    sum = 12
    @mock
    |> stub(:add, %AddResponse{sum: 12})

    request = %AddRequest{}
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == sum

    GrpcMock.verify!(@mock)
  end

  test "stub - func", %{channel: channel} do
    x = 13

    @mock
    |> stub(:add, fn req, _ -> %AddResponse{sum: req.x} end)

    request = %AddRequest{x: x}
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == x

    GrpcMock.verify!(@mock)
  end

  test "expect - struct", %{channel: channel} do
    sum = 12

    @mock
    |> expect(:add, %AddResponse{sum: 12})

    request = %AddRequest{}
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == sum

    GrpcMock.verify!(@mock)
  end

  test "expect - multiple operations", %{channel: channel} do
    x = 2
    y = 3
    sum = x + y
    prod = x * y

    @mock
    |> expect(:add, fn req, _ -> %AddResponse{sum: req.x + req.y} end)
    |> expect(:mult, fn req, _ -> %AddResponse{sum: req.x * req.y} end)

    request = %AddRequest{x: x, y: y}
    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == sum

    request = %MultRequest{x: x, y: y}
    assert {:ok, reply} = channel |> Stub.mult(request)
    assert reply.prod == prod

    GrpcMock.verify!(@mock)
  end

  test "expect - one invocation", %{channel: channel} do
    x = 5

    @mock
    |> expect(:add, fn req, _ -> %AddResponse{sum: req.x} end)

    request = %AddRequest{x: x}
    assert {:ok, reply} = channel |> Stub.add(request)

    assert reply.sum == x

    GrpcMock.verify!(@mock)
  end

  test "expect - 3 invocations", %{channel: channel} do
    x = 9
    sum = 42

    @mock
    |> expect(:add, fn req, _ -> %AddResponse{sum: req.x} end)
    |> expect(:add, 2, fn _, _ -> %AddResponse{sum: sum} end)

    request = %AddRequest{x: x}
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
    |> expect(:add, fn req, _ -> %AddResponse{sum: req.x} end)

    assert_raise(
      GrpcMock.VerificationError,
      ~r/CalcMock.add.*invoked 0 times/,
      fn -> GrpcMock.verify!(@mock) end
    )
  end

  test "mix expect and stub", %{channel: channel} do
    x = 9
    prod = 42

    @mock
    |> stub(:mult, fn _, _ -> %MultResponse{prod: prod} end)
    |> expect(:add, 2, fn req, _ -> %AddResponse{sum: req.x} end)

    request = %AddRequest{x: x}
    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == x

    request = %MultRequest{}
    assert {:ok, reply} = channel |> Stub.mult(request)
    assert reply.prod == prod

    request = %AddRequest{x: x}
    assert {:ok, reply} = channel |> Stub.add(request)
    assert reply.sum == x

    GrpcMock.verify!(@mock)
  end
end
