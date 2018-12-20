defmodule GrpcMockTest do
  use ExUnit.Case
  doctest GrpcMock

  alias GRPC.Server
  alias Helloworld.{Greeter.Stub, HelloReply, HelloRequest}

  import GrpcMock

  @mock HelloServer

  setup_all do
    Server.start(@mock, 50_051)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    {:ok, %{channel: channel}}
  end

  test "use stub - content = qwerty", %{channel: channel} do
    @mock
    |> stub(:say_hello, fn _req, _ -> HelloReply.new(message: "qwerty") end)

    request = HelloRequest.new()
    assert {:ok, reply} = channel |> Stub.say_hello(request)

    assert reply.message == "qwerty"

    GrpcMock.verify!(@mock)
  end

  test "use stub - content = asdfgh", %{channel: channel} do
    content = "asdfgh"

    @mock
    |> stub(:say_hello, fn req, _ -> HelloReply.new(message: req.name) end)

    request = HelloRequest.new(name: content)
    assert {:ok, reply} = channel |> Stub.say_hello(request)

    assert reply.message == content

    GrpcMock.verify!(@mock)
  end

  test "expect - one invocation", %{channel: channel} do
    content = "asdfgh"

    @mock
    |> expect(:say_hello, fn req, _ -> HelloReply.new(message: req.name) end)

    request = HelloRequest.new(name: content)
    assert {:ok, reply} = channel |> Stub.say_hello(request)

    assert reply.message == content

    GrpcMock.verify!(@mock)
  end

  test "expect - two invocations", %{channel: channel} do
    content = "asdfgh"

    @mock
    |> expect(:say_hello, fn req, _ -> HelloReply.new(message: req.name) end)
    |> expect(:say_hello, fn _, _ -> HelloReply.new(message: "fred") end)

    request = HelloRequest.new(name: content)
    assert {:ok, reply} = channel |> Stub.say_hello(request)
    assert reply.message == content

    assert {:ok, reply} = channel |> Stub.say_hello(request)
    assert reply.message == "fred"

    GrpcMock.verify!(@mock)
  end

  test "expect - fail" do
    @mock
    |> expect(:say_hello, fn req, _ -> HelloReply.new(message: req.name) end)

    assert_raise(
      GrpcMock.VerificationError,
      ~r/HelloServer.say_hello.*invoked 0 times/,
      fn -> GrpcMock.verify!(@mock) end
    )
  end
end
