defmodule MixDarkly.Supervisor do
  use Supervisor

  @spec start_link(config :: MixDarkly.Config.t()) :: Supervisor.on_start()
  def start_link(config) do
    Supervisor.start_link(__MODULE__, config)
  end

  def init(config) do
    children = [
      worker(MixDarkly.EventProcessor, [config.sdk_key, config.event_processor_config]),
      worker(MixDarkly.UpdateProcessor, []),
      worker(MixDarkly.FeatureStore, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
