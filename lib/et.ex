defmodule ET do
  def compose([{transducer, new_state} | rest], {reducer, old_state}) do
    compose(rest, {transducer.(reducer), [new_state | old_state]})
  end
  def compose([], reducer), do: reducer

  def prepend_state({msg, {acc, state}}, new_state), do: {msg, {acc, [new_state | state]}}

  def mapping(fun) do
    {fn step -> fn trans_wrap ->
       case trans_wrap do
         [nil | state]               -> step.(state)
         {acc, [nil | state]}        -> step.({acc, state})
         {input, acc, [nil | state]} -> step.({fun.(input), acc, state})
       end |> prepend_state(nil)
     end end, nil}
  end

  def reduce(coll, init, {trans, state}) do
    {msg, {acc, new_state}} = Enumerable.reduce(coll, {:cont, {init, state}}, reducify(trans))
    {:halt, {result, _state}} = trans.({acc, new_state})
    result
  end

  def reduce(coll, {trans, state}) do
    {:cont, {init, new_state}} = trans.(state)
    reduce(coll, init, {trans, new_state})
  end

  defp reducify(trans), do: fn input, {acc, state} -> trans.({input, acc, state}) end
end
