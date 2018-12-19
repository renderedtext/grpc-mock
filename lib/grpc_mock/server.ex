defmodule GrpcMock.Server do
  @moduledoc false

  use GenServer

  def start_link(_options) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def add_expectation(mock, fname, expectation) do
    GenServer.call(__MODULE__, {:add_expectation, mock, fname, expectation})
  end

  def verify(mock) do
    GenServer.call(__MODULE__, {:verify, mock})
  end

  def fetch_fun(mock, fname) do
    GenServer.call(__MODULE__, {:fetch_fun, mock, fname})
  end

  def init(:ok) do
     {:ok, %{}}
  end

  def handle_call({:add_expectation, mock, fname, expectation}, _from, state) do
    state = update_in(state, [Access.key(mock, %{}), Access.key(fname, nil)], fn owned_expectations ->
      merge_expectations(owned_expectations, expectation)
    end)

    {:reply, :ok, state}
  end

  def handle_call({:fetch_fun, mock, fname}, _from, state) do
    case get_in(state, [mock, fname]) do
      nil ->
        {:reply, :no_expectation, state}

      {total, [], nil} ->
        {:reply, {:out_of_expectations, total}, state}

      {_, [], stub} ->
        {:reply, {:ok, stub}, state}

      {total, [call | calls], stub} ->
        new_state = put_in(state[mock][fname], {total, calls, stub})
        {:reply, {:ok, call}, new_state}
    end
  end

  def handle_call({:verify, mock}, _from, state) do
    pending = for {fname, {total, [_ | _] = calls, _}} <- Map.get(state, mock, %{}) do
      {fname, total, length(calls)}
    end

    new_state = state |> Map.delete(mock)

    {:reply, pending, new_state}
  end

  defp merge_expectations(nil, expectation), do: expectation
  defp merge_expectations({current_n, current_calls, current_stub}, {n, calls, stub}) do
    {current_n + n, current_calls ++ calls, stub || current_stub}
  end
end
