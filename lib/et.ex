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

  def reduce(coll, init \\ nil, trans) do
    {_msg, new_state} =
      Enumerable.reduce(coll, trans.({:init,init}), reducify(trans))
    {:fin, result} = trans.({:fin, new_state})
    result    
  end

  defp reducify(trans), do: fn input, state -> trans.({:cont, input, state}) end

  def stateful(fun, init_state) do
    fn step ->
      fn
        # completion
        {:fin, [_my_state | rem_state]} ->
          step.({:fin, rem_state})
        # action
        {:cont, input, [my_state | rem_state]} ->
          case fun.(input, my_state) do
            {:halt, new_state} -> {:halt, [new_state | rem_state]}
            {:cont, input, new_state} ->
              step.({:cont, input, rem_state})
              |> prepend_state(new_state)
          end
        # initialization
        {:init, init} -> step.({:init, init}) |> prepend_state(init_state)
      end
    end
  end
end
