# Protocol a user struct must implement in order to utilize certain lti 1.3 functionality
defprotocol Oli.Lti_1p3.Lti_1p3_User do
  def get_platform_roles(user)
  def get_context_roles(user, context_id)
end

defimpl Oli.Lti_1p3.Lti_1p3_User, for: Any do
  def get_platform_roles(_user), do: []
  def get_context_roles(_user, _context_id), do: []
end
