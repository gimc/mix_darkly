defmodule MixDarkly.UpdateProcessor do
  @moduledoc """
  Connects to LD event streaming endpoint and listens for updates
  """

  use GenServer

  def start_link(), do: GenServer.start_link(__MODULE__, false)

  @spec is_initialized?(pid) :: {:reply, boolean}
  def is_initialized?(pid), do: GenServer.call(pid, :is_initialized?)

  @spec initialize(pid) :: :ok
  def initialize(pid), do: GenServer.cast(pid, :initialize)

  def init(state), do: {:ok, state}
  def handle_call(:is_initialized?, _from, state), do: {:reply, state, state}
  def handle_cast(:initialize, state), do: {:noreply, true}
end
