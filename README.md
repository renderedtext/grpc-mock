# grpc-mock
Easy gRPC server mocking for [grpc Elixir library](https://github.com/tony612/grpc-elixir)

A lot of concepts and code taken from [mox library](https://github.com/plataformatec/mox).

## Example

Create mocked gRPC server:
```
GrpcMock.defmock(MockedServer, for: Helloworld.Greeter.Service)
```
Start gRPC server:
```
GRPC.Server.start(MockedServer, 50051)
```
Connect to the server:
```
{:ok, channel} = GRPC.Stub.connect("localhost:50051")
```
Setup stub on mocked server:
```
GrpcMock.stub(MockedServer, :say_hello, fn(request, stream) ->
  Helloworld.HelloReply.new(message: request.name)
end)
```
Call the server:
```
name = "bob"
request = Helloworld.HelloRequest.new(name: name)
assert {:ok, reply} = Helloworld.Greeter.Stub.say_hello(channel, request)
assert reply.message == name
```


Copyright 2018 RenderedText

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
