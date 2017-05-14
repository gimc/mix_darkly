defmodule MixDarkly.UserTest do
  use ExUnit.Case

  alias MixDarkly.User, as: Sut

  test "get value of user attribute when it is set" do
    user = %Sut{ip: "127.0.0.1"}
    {value, pass} = Sut.value_of(user, "ip")

    assert value == "127.0.0.1"
    assert pass == false
  end

  test "get value of unset user attribute" do
    user = %Sut{ip: nil}
    {value, pass} = Sut.value_of(user, "ip")

    assert value == nil
    assert pass == true
  end

  test "get value of custom attribute" do
    user = %Sut{custom: [foo: "bar"]}
    {value, pass} = Sut.value_of(user, "foo")

    assert value == "bar"
    assert pass == false
  end

  test "get value of unset custom attribute" do
    user = %Sut{custom: [foo: "bar"]}
    {value, pass} = Sut.value_of(user, "idontexist")

    assert value == nil
    assert pass == true
  end
end
