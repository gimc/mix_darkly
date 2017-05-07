defmodule MixDarkly.ClientTest do
  use ExUnit.Case

  alias MixDarkly.Client, as: Sut
  alias MixDarkly.FeatureStore
  alias MixDarkly.UpdateProcessor

  test "Returns bool variation for valid key" do
    client = nil
    user = nil
    default_value = false
    expected_value = true

    {:ok, value} = Sut.bool_variation(client, "key", user, default_value)

    assert value == expected_value
  end

  test "Returns default bool variation for non-existing key" do
    {:ok, value} = Sut.bool_variation(nil, "idontexist", nil, true)
    assert value == true
  end

  test "Using bool_variation to return non-boolean value returns error" do
    {result, reason} = Sut.bool_variation(nil, "idontexist", nil, "i am not a bool")
    assert result == :error
    assert String.starts_with?(reason, "Incompatible type")
  end

  test "Returns default variation when client is offline" do
    client = %{:config => %{:offline => true}}

    {:ok, value} = Sut.variation(client, "key", %{}, "foo")

    assert value == "foo"
  end

  test "evaluate returns error when the user key is nil" do
    {result, reason} = Sut.evaluate(nil, "", %{:key => nil}, nil)
    assert result == :error
    assert reason == "User key cannot be nil"
  end

  test "evaluate returns error when the update processor is not initialized" do
    {:ok, update_processor} = UpdateProcessor.start_link()
    {:ok, feature_store} = FeatureStore.start_link()
    client = %{:update_processor => update_processor,
               :feature_store => feature_store,
               :config => %{:offline => false, :use_ldd => false}}
    user = %{:key => "uniqueid"}

    {result, reason} = Sut.evaluate(client, "", user, nil)

    assert result == :error
    assert reason == "Client not initialized"
  end

  test "evaluate returns true when feature flag exists" do
    {:ok, update_processor} = UpdateProcessor.start_link()
    {:ok, feature_store} = FeatureStore.start_link()
    client = %{:update_processor => update_processor,
               :feature_store => feature_store,
               :config => %{:offline => false, :use_ldd => false}}
    user = %{:key => "uniqueid"}

    UpdateProcessor.initialize(update_processor)
    FeatureStore.put(feature_store, %{:key => "foo", :version => 2, :on => true, :variations => [true, false]})

    {:ok, value, version} = Sut.evaluate(client, "foo", user, false)

    assert value == true
    assert version == 2
  end
end
