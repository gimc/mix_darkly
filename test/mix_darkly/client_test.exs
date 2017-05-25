defmodule MixDarkly.ClientTest do
  use ExUnit.Case

  alias MixDarkly.Client, as: Sut
  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.User

  defp setup do
    client = %Sut{
      sdk_key: "123456",
      config: %MixDarkly.Config{
        event_processor_config: %MixDarkly.EventProcessor.Config{}
      }
    }

    MixDarkly.Supervisor.start_link(client)

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

    FeatureStore.put(flag)

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

  test "evaluate returns true when feature flag exists" do
    context = setup()
    user = %User{key: "uniqueid"}

    flag = %FeatureFlag{key: "foo",
                        version: 2,
                        on: true,
                        variations: [true, false],
                        targets: [%{values: ["uniqueid"], variation: 0}]}

    FeatureStore.put(flag)

    {:ok, value, version} = Sut.evaluate(context[:client], "foo", user, false)

    assert value == true
    assert version == 2
  end
end
