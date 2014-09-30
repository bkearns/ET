defmodule ET do
  def compose([{transducer, new_state} | rest], {reducer, old_state}) do
    compose(rest, {transducer.(reducer), [new_state | old_state]})
  end
  def compose([], reducer), do: reducer

  def prepend_state({msg, acc, state}, new_state), do: {msg, acc, [new_state | state]}

  def mapping(fun) do
    {fn step -> fn trans_wrap ->
       case trans_wrap do
         {:init, [nil | state]} -> step.({:init, state})
         {:close, acc, [nil | state]} -> step.({:close, acc, state})
         {:cont, input, acc, [nil | state]} -> step.({:cont, fun.(input), acc, state})
       end |> prepend_state(nil)
     end end, nil}
  end
end
