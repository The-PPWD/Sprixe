defmodule Client.Input do
  use GenServer, restart: :transient, significant: true

  @key_esc 27

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
      :shutdown -> Client.Connection.disconnect()
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

  defp key_to_action(@key_esc), do: :shutdown
  defp key_to_action(?w), do: :move_forward
  defp key_to_action(?s), do: :move_backward
  defp key_to_action(?a), do: :move_left
  defp key_to_action(?d), do: :move_right
  defp key_to_action(?q), do: :turn_left
  defp key_to_action(?e), do: :turn_right
  defp key_to_action(_), do: nil
end
