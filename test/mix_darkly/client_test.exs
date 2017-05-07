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
    client = nil
    user = nil
    
    {:ok, value} = Sut.bool_variation(client, "idontexist", user, true)

    assert value == true
  end
end
