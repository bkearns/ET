defmodule ET do
  def compose([{transducer, new_state} | rest], {reducer, old_state}) do
    compose(rest, {transducer.(reducer), [new_state | old_state]})
  end
  def compose([], reducer), do: reducer
end
