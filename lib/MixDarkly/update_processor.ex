defmodule MixDarkly.UpdateProcessor do
  @moduledoc """
  Connects to LD event streaming endpoint and listens for updates
  """
  use GenServer

  def start_link(), do: GenServer.start_link(__MODULE__, false, [name: :update_processor])

  @spec is_initialized? :: {:reply, boolean}
  def is_initialized?, do: {:reply, true}

  @spec initialize :: :ok
  def initialize, do: :ok

  def init(state), do: {:ok, state}
end
