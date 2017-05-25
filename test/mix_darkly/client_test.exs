defmodule MixDarkly.ClientTest do
  use ExUnit.Case

  alias MixDarkly.Client, as: Sut
  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.UpdateProcessor
  alias MixDarkly.User

  defp setup do
    {:ok, update_processor} = UpdateProcessor.start_link()
    UpdateProcessor.initialize(update_processor)

    {:ok, feature_store} = FeatureStore.start_link()

    client = %Sut{
      update_processor: update_processor,
      feature_store: feature_store
    }

    user = %User{
      key: "User1",
      ip: "127.0.0.1"
    }

    [client: client, user: user]
  end

  test "Returns bool variation for valid key" do
    context = setup()

    flag = %FeatureFlag{
      key: "BooleanFlag",
      rules: [%{
        clauses: [%{
          attribute: "ip", op: "eq", values: ["127.0.0.1"], negate: false
        }],
        variation_or_rollout: %{variation: 1, rollout: nil}
      }],
      variations: [false, true],
      fallthrough: %{variation: 0, rollout: nil}
    }

    FeatureStore.put(context[:client].feature_store, flag)

    default_value = false
    expected_value = true

    {:ok, value} = Sut.bool_variation(context[:client], "BooleanFlag", context[:user], default_value)

    assert value == expected_value
  end

  test "Returns default bool variation for non-existing key" do
    context = setup()
    {:ok, value} = Sut.bool_variation(context[:client], "idontexist", context[:user], true)
    assert value == true
  end

  test "Using bool_variation to return non-boolean value returns error" do
    context = setup()
    {result, reason} = Sut.bool_variation(context[:client], "idontexist", context[:user], "i am not a bool")
    assert result == :error
    assert String.starts_with?(reason, "Incompatible type")
  end

  test "Returns default variation when client is offline" do
    client = %{config: %{offline: true}}

    {:ok, value} = Sut.variation(client, "key", %{}, "foo")

    assert value == "foo"
  end

  test "evaluate returns error when the user key is nil" do
    {result, reason} = Sut.evaluate(nil, "", %{key: nil}, nil)
    assert result == :error
    assert reason == "User key cannot be nil"
  end

  test "evaluate returns error when the update processor is not initialized" do
    {:ok, update_processor} = UpdateProcessor.start_link()
    {:ok, feature_store} = FeatureStore.start_link()
    client = %{update_processor: update_processor,
               feature_store: feature_store,
               config: %{offline: false, use_ldd: false}}
    user = %{key: "uniqueid"}

    {result, reason} = Sut.evaluate(client, "", user, nil)

    assert result == :error
    assert reason == "Client not initialized"
  end

  test "evaluate returns true when feature flag exists" do
    {:ok, update_processor} = UpdateProcessor.start_link()
    {:ok, feature_store} = FeatureStore.start_link()

    client = %Sut{update_processor: update_processor,
                  feature_store: feature_store,
                  config: %{
                    offline: false, use_ldd: false
                  }}

    user = %User{key: "uniqueid"}

    flag = %FeatureFlag{key: "foo",
                        version: 2,
                        on: true,
                        variations: [true, false],
                        targets: [%{values: ["uniqueid"], variation: 0}]}

    UpdateProcessor.initialize(update_processor)
    FeatureStore.put(feature_store, flag)

    {:ok, value, version} = Sut.evaluate(client, "foo", user, false)

    assert value == true
    assert version == 2
  end
end
