defmodule ApiGatewayWeb.Gql.Resolvers.MediaChat do
  alias ApiGateway.Models

  def create_new_media_chat(_, %{data: _}, %{context: %{current_user: nil}}) do
    ApiGatewayWeb.Gql.Utils.Errors.forbidden_error()
  end

  def create_new_media_chat(
        _,
        %{data: %{recipient_id: recipient_id}},
        %{context: %{current_user: current_user}}
      ) do
    Models.MediaChat.create_new_chat(%{recipient_id: recipient_id}, current_user)
    |> case do
      :invalid_user_invited ->
        ApiGatewayWeb.Gql.Utils.Errors.user_input_error("Invalid user invited")

      {:ok, chat_id, _redis_key} ->
        {:ok, %{chat_id: chat_id}}
    end
  end

  def check_user_can_enter_media_chat(
        _,
        %{data: %{chat_id: chat_id}},
        %{context: %{current_user: current_user}}
      ) do
    Models.MediaChat.user_is_chat_member?(chat_id, current_user.id)
    |> case do
      false ->
        {:ok, false}

      true ->
        {:ok, true}
    end
  end

  def get_media_chat_info(
        _,
        %{data: %{chat_id: chat_id}},
        %{context: %{current_user: current_user}}
      ) do
    Models.MediaChat.get_media_chat_info(chat_id, current_user)
    |> case do
      {:error, :forbidden} ->
        ApiGatewayWeb.Gql.Utils.Errors.forbidden_error()

      reply ->
        {:ok, reply}
    end
  end
end
