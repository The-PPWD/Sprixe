defmodule Client.Input do
  use GenServer, restart: :transient, significant: true

  @key_esc 27
  @key_up 259
  @key_down 258
  @key_left 260
  @key_right 261

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    ExNcurses.listen()
    {:ok, []}
  end

  def handle_info({:ex_ncurses, :key, key}, state) do
    action = key_to_action(key)

    case action do
      nil -> nil
      _ -> Client.Connection.send_input(action)
    end

    case action do
      :shutdown -> {:stop, action, state}
      _ -> {:noreply, state}
    end
  end

  def terminate(_, _) do
    ExNcurses.stop_listening()
  end

  defp key_to_action(key) when key === ?q or key === @key_esc, do: :shutdown
  defp key_to_action(key) when key === ?w or key === @key_up, do: :up
  defp key_to_action(key) when key === ?s or key === @key_down, do: :down
  defp key_to_action(key) when key === ?a or key === @key_left, do: :left
  defp key_to_action(key) when key === ?d or key === @key_right, do: :right
  defp key_to_action(_), do: nil
end
