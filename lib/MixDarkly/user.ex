defmodule MixDarkly.User do
  defstruct key: "",
    secondary: "",
    ip: "",
    country: "",
    email: "",
    first_name: "",
    last_name: "",
    avatar: "",
    name: "",
    anonymous: nil,
    custom: [],
    derived: %{}

  @type t :: %MixDarkly.User{}

  @spec value_of(user :: User.t(), attribute :: String.t()) :: {value :: term, pass :: boolean}
  def value_of(user, attribute) do
    is_user_attribute = fn attr -> (%MixDarkly.User{} |> Map.keys |> Enum.member?(attr)) != nil end
    atom = String.to_atom(attribute)
    with true <- is_user_attribute.(atom),
         {:ok, value} <- Map.fetch(user, atom),
         true <- value != nil
    do
      {value, false}
    else
      _ -> get_custom_value(user, atom)
    end
  end

  @spec get_custom_value(user :: User.t(), attribute :: atom) :: {value :: term, pass :: boolean}
  defp get_custom_value(%{:custom => nil}, _attribute), do: {nil, true}
  defp get_custom_value(user, attribute) do
    case Keyword.get(user.custom, attribute) do
      nil -> {nil, true}
      value -> {value, false}
    end
  end
end
