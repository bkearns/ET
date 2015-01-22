defmodule ET do
  import ET.Transducer

  def prepend_state({msg, state}, new_state), do: {msg, [new_state | state]}

  def reduce(coll, reducer) do
    do_reduce(coll, reducer.(:init), reducer)
  end

  defp do_reduce(coll, {:cont, state}, reducer) do
    case Transducible.next(coll) do
      {elem, rem} -> do_reduce(rem, reducer.({:cont, elem, state}), reducer)
      :done      -> finish_reduce(state, reducer)
    end
  end
  defp do_reduce(_coll, {:halt, state}, reducer), do: finish_reduce(state, reducer)

  defp finish_reduce(state, reducer) do
    {:fin, result} = reducer.({:fin, state})
    result
  end

end
