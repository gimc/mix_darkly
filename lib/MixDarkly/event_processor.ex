defmodule MixDarkly.EventProcessor.Config do
  defstruct sdk_key: "",
            batch_interval: 30,
            events_uri: "",
            version: Mix.Project.config[:version]

  @type t :: %MixDarkly.EventProcessor.Config{
    :sdk_key => String.t(),
    :batch_interval => integer,
    :events_uri => String.t()
  }
end

defmodule MixDarkly.EventProcessor do
  use GenServer
  require Logger
  alias MixDarkly.EventProcessor.Config

  defstruct config: %Config{},
            events: []

  @type t :: %MixDarkly.EventProcessor{
    :config => Config.t(),
    :events => []
  }

  # API
  @spec start_link(config :: MixDarkly.EventProcessor.Config.t(), opts :: [term]) :: GenServer.on_start()
  def start_link(config, opts) do
    GenServer.start_link(__MODULE__, config, opts)
  end

  @spec init(config :: MixDarkly.EventProcessor.Config.t()) ::
    {:ok, MixDarkly.EventProcessor.t()}
  def init(config) do
    schedule_work(config.batch_interval)
    {:ok, %MixDarkly.EventProcessor{
      config: config,
      events: []
    }}
  end

  @spec send(pid, event :: term) :: :ok
  def send(pid, event) do
    GenServer.cast(pid, {:send, event})
  end

  # Callbacks
  def handle_cast({:send, _event}, _from, %{config: %{send_events: false}} = state) do
    {:no_reply, state}
  end
  def handle_cast({:send, event}, _from, state) do
    {:no_reply, %{state | events: [event|state.events]}}
  end

  def handle_info(:flush, _from, %{events: events} = state) when length(events) == 0,
    do: {:no_reply, state}
  def handle_info(:flush, _from, state) do
    with uri <- state.config.events_uri <> "/bulk",
         body <- Poison.encode!(state, state.events),
         headers <- [{"Authorization", state.config.sdk_key},
                    {"Content-Type", "application/json"},
                    {"User-Agent", "MixDarkly/" <> state.config.version}],
         {:ok, _} <- HTTPoison.post(uri, body, headers)
    do
      {:noreply, %{state | events: []}}
    else
      {:error, error} ->
        Logger.error(error)
        {:stop, error.reason, state}
    end
  end

  defp schedule_work(batch_interval) do
    Process.send_after(self(), :flush, batch_interval * 1000)
  end
end
