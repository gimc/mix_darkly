defmodule MixDarkly.Event.FeatureRequest do
  alias MixDarkly.User

  defstruct creation_date: DateTime.utc_now,
            key: "",
            kind: :feature_request_event,
            user: nil,
            value: nil,
            default: nil,
            version: 0,
            prereq_of: nil

  @type t :: %{
    :creation_date => DateTime.t(),
    :key => atom,
    :kind => String.t(),
    :user => User.t(),
    :value => term,
    :default => term,
    :version => integer,
    :prereq_of => String.t()
  }

  @spec get_base(event :: FeatureRequest.t()) :: %{}
  def get_base(event) do
    %{
      creation_date: event.creation_date,
      key: event.key,
      user: event.user,
      kind: :feature_request_event
    }
  end
end
