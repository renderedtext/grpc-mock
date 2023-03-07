defmodule AddRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:x, 1, type: :float)
  field(:y, 2, type: :float)
end

defmodule AddResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:sum, 1, type: :float)
end

defmodule MultRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:x, 1, type: :float)
  field(:y, 2, type: :float)
end

defmodule MultResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:prod, 1, type: :float)
end

defmodule Calculator.Service do
  @moduledoc false
  use GRPC.Service, name: "Calculator", protoc_gen_elixir_version: "0.11.0"

  rpc(:Add, AddRequest, AddResponse)

  rpc(:Mult, MultRequest, MultResponse)
end

defmodule Calculator.Stub do
  @moduledoc false
  use GRPC.Stub, service: Calculator.Service
end
