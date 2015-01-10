defmodule ET do
  def compose([transducer | rest], reducer) do
    compose(rest, transducer.(reducer))
  end
  def compose([], reducer), do: reducer

  def prepend_state({msg, state}, new_state), do: {msg, [new_state | state]}

  def map(fun) do
    fn step ->
      fn
        {:fin, state}         -> step.({:fin, state})
        {:cont, input, state} -> step.({:cont, fun.(input), state})
        {:init, init}         -> step.({:init, init})
      end
    end
  end

  def reduce(coll, init \\ nil, reducer) do
    do_reduce(coll, reducer.({:init, init}), reducer)
  end

  defp do_reduce(coll, {:cont, state}, reducer) do
    case Transducible.next(coll) do
      {elem, rem} -> do_reduce(rem, reducer.({:cont, elem, state}), reducer)
      :empty      -> finish_reduce(state, reducer)
    end
  end
  defp do_reduce(_coll, {:halt, state}, reducer), do: finish_reduce(state, reducer)

  defp finish_reduce(state, reducer) do
    {:fin, result} = reducer.({:fin, state})
    result
  end

  def stateful(fun, init_state) do
    fn reducer ->
      fn
        # completion
        {:fin, [_my_state | rem_state]} ->
          reducer.({:fin, rem_state})
        # action
        {:cont, input, [my_state | rem_state]} ->
          case fun.(input, my_state) do
            {:halt, new_state} -> {:halt, [new_state | rem_state]}
            {:cont, input, new_state} ->
              reducer.({:cont, input, rem_state})
              |> prepend_state(new_state)
          end
        # initialization
        {:init, init} -> reducer.({:init, init}) |> prepend_state(init_state)
      end
    end
  end
end
