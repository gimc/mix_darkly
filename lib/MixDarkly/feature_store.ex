defmodule MixDarkly.FeatureStore do
  alias MixDarkly.FeatureFlag

  def start_link do
    Agent.start_link(fn -> %{} end, name: :feature_store)
  end

  @spec get(key :: String.t()) ::
    {:ok, FeatureFlag.feature_flag()} |
    {:error, key :: String.t()}
  def get(key) do
    case Agent.get(:feature_store, &(Map.fetch(&1, key))) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, key}
    end
  end

  @spec put(feature_flag :: FeatureFlag.feature_flag()) :: :ok
  def put(feature_flag),
    do: Agent.update(:feature_store, &(Map.put(&1, feature_flag.key, feature_flag)))
end
