defprotocol Oli.Lti_1_3.MessageValidator do

  @spec can_validate(any) :: boolean
  def can_validate(jwt_body)

  @spec validate(any) :: {:ok} | {:error, String.t()}
  def validate(jwt_body)
end
