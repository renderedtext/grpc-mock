defmodule AddRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          x: float,
          y: float
        }
  defstruct [:x, :y]

  field :x, 1, type: :float
  field :y, 2, type: :float
end

defmodule AddResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          sum: float
        }
  defstruct [:sum]

  field :sum, 1, type: :float
end

defmodule MultRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          x: float,
          y: float
        }
  defstruct [:x, :y]

  field :x, 1, type: :float
  field :y, 2, type: :float
end

defmodule MultResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          prod: float
        }
  defstruct [:prod]

  field :prod, 1, type: :float
end

defmodule Calculator.Service do
  @moduledoc false
  use GRPC.Service, name: "Calculator"

  rpc :Add, AddRequest, AddResponse
  rpc :Mult, MultRequest, MultResponse
end

defmodule Calculator.Stub do
  @moduledoc false
  use GRPC.Stub, service: Calculator.Service
end
