defmodule MixDarkly.ClientTest do
  use ExUnit.Case

  alias MixDarkly.Client, as: Sut

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
    client = %{
      :config => %{
        :offline => true
      }
    }

    {:ok, value} = Sut.variation(client, "key", %{}, "foo")

    assert value == "foo"
  end
end
