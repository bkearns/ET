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


  def reduce(coll, {trans, state}) do
    do_reduce(coll, {:init, state}, trans)
  end

  def reduce(coll, init, {trans, state}) do
    do_reduce(coll, {:cont, init, state}, trans)
  end

  defp do_reduce(coll, {:init, state}, trans) do
    do_reduce(coll, trans.({:init, state}), trans)
  end
  defp do_reduce(coll, {:cont, acc, state}, trans) do
    case Transducible.next(coll) do
      :empty -> do_reduce(coll, {:close, acc, state}, trans)
      {next, rem} ->
        do_reduce(rem, trans.({:cont, next, acc, state}), trans)
    end
  end
  defp do_reduce(coll, {:halt, acc, state}, trans) do
    do_reduce(coll, {:close, acc, state}, trans)
  end
  defp do_reduce(_coll, {:close, acc, state}, trans) do
    {_msg, result, _state} = trans.({:close, acc, state})
    result
  end
end
