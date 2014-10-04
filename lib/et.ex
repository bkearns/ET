defmodule ET do
  def compose([transducer | rest], reducer) do
    compose(rest, transducer.(reducer))
  end
  def compose([], reducer), do: reducer

  def prepend_state({msg, {acc, state}}, new_state), do: {msg, {acc, [new_state | state]}}

  def mapping(fun) do
    fn step ->
      sub_state = step.(:state)
      fn
        :state                    -> sub_state
        state when is_list(state) -> step.(state)
        {acc, state}              -> step.({acc, state})
        {input, acc, state}       -> step.({fun.(input), acc, state})
      end
    end
  end

  def reduce(coll, init, trans) do
    state = trans.(:state)
    {_msg, {acc, new_state}} = Enumerable.reduce(coll, {:cont, {init, state}}, reducify(trans))
    {:halt, {result, _state}} = trans.({acc, new_state})
    result
  end

  def reduce(coll, trans) do
    state = trans.(:state)
    {:cont, {init, new_state}} = trans.(state)
    reduce(coll, init, trans)
  end

  defp reducify(trans), do: fn input, {acc, state} -> trans.({input, acc, state}) end

  def stateful_transducer(fun, init_state) do
    fn step ->
      sub_state = step.(:state)
      fn
        # state_builder
        :state -> [init_state | sub_state]
        # initialization
        [my_state | rem_state] -> prepend_state(step.(rem_state), my_state)
        # completion
        {acc, [my_state | rem_state]} -> prepend_state(step.({acc, rem_state}), my_state)
        # action
        {input, acc, [my_state | rem_state]} ->
          case fun.(input, acc, my_state) do
            {:halt, acc, new_state} -> {:halt, {acc, [new_state | rem_state]}}
            {:cont, input, acc, new_state} ->
              prepend_state(step.({input, acc, rem_state}), new_state)
          end
       end
    end
  end
end
