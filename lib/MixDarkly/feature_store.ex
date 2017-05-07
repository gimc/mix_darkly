defmodule MixDarkly.FeatureStore do
  alias MixDarkly.FeatureFlag

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec get(pid, key :: String.t()) :: {:ok, FeatureFlag.feature_flag()}
  def get(pid, key), do: Agent.get(pid, &(Map.fetch(&1, key)))

  @spec put(pid, feature_flag :: FeatureFlag.feature_flag()) :: :ok
  def put(pid, feature_flag),
    do: Agent.update(pid, &(Map.put(&1, feature_flag[:key], feature_flag)))
end
