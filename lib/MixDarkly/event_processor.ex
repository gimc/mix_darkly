defmodule MixDarkly.EventProcessor.Config do
  defstruct batch_interval: 30,
            events_uri: Application.fetch_env!(:mix_darkly, :events_uri),
            version: Mix.Project.config[:version]

  @type t :: %MixDarkly.EventProcessor.Config{
    :batch_interval => integer,
    :events_uri => String.t(),
    :version => integer
  }
end

defmodule MixDarkly.EventProcessor do
  use GenServer
  require Logger
  alias MixDarkly.EventProcessor.Config

  defstruct sdk_key: nil,
            config: %Config{},
            events: []

  @type t :: %MixDarkly.EventProcessor{
    :sdk_key => String.t(),
    :config => Config.t(),
    :events => []
  }

  defimpl String.Chars do
    def to_string(%{config: config, events: events}) do
      """
      Event Processor
      #{length(events)} in events queue
      SDK Key: #{config.sdk_key}
      Sending every #{config.batch_interval} seconds
        to #{config.events_uri}
      Version: #{config.version}
      """
    end
  end

  # API
  @spec start_link(sdk_key :: String.t(), config :: Config.t(), opts :: [term]) :: GenServer.on_start()
  def start_link(sdk_key, config, opts \\ []) do
    GenServer.start_link(__MODULE__, [sdk_key, config], Keyword.merge(opts, [name: :event_processor]))
  end

  @spec init(sdk_key :: String.t(), config :: Config.t()) :: {:ok, MixDarkly.EventProcessor.t()}
  def init(sdk_key, config) do
    schedule_work(config.batch_interval)
    {:ok, %MixDarkly.EventProcessor{
      sdk_key: sdk_key,
      config: config,
      events: []
    }}
  end

  @spec send(event :: MixDarkly.Event.FeatureRequest.t()) :: :ok
  def send(event) do
    GenServer.cast(:event_processor, {:send, event})
  end

  # Callbacks
  def handle_cast({:send, _event}, %MixDarkly.EventProcessor{config: %{send_events: false}} = state) do
    {:noreply, state}
  end
  def handle_cast({:send, event}, state) do
    {:noreply, %{state | events: [event|state.events]}}
  end

  def handle_info(:flush, %{events: events} = state) when length(events) == 0 do
    schedule_work(state.config.batch_interval)
    {:noreply, state}
  end
  def handle_info(:flush, state) do
    with uri <- state.config.events_uri <> "/bulk",
         body <- Poison.encode!(state, state.events),
         headers <- [{"Authorization", state.sdk_key},
                    {"Content-Type", "application/json"},
                    {"User-Agent", "MixDarkly/" <> state.config.version}],
         {:ok, _} <- HTTPoison.post(uri, body, headers)
    do
      schedule_work(state.config.batch_interval)
      {:noreply, %{state | events: []}}
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error when attempting to send events to '#{state.config.events_uri}'")
        {:stop, reason, state}
    end
  end

  defp schedule_work(batch_interval) do
    Process.send_after(self(), :flush, batch_interval * 1000)
  end
end
