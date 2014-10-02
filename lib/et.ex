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
    {_msg, {acc, new_state}} = Enumerable.reduce(coll, {:cont, {init, state}}, reducify(trans))
    {:halt, {result, _state}} = trans.({acc, new_state})
    result
  end

  def reduce(coll, {trans, state}) do
    {:cont, {init, new_state}} = trans.(state)
    reduce(coll, init, {trans, new_state})
  end

  defp reducify(trans), do: fn input, {acc, state} -> trans.({input, acc, state}) end

  def stateful_transducer(fun, init_state) do
    {fn step -> 
      # initialization
      fn [my_state | rem_state] -> prepend_state(step.(rem_state), my_state)
      # completion
         {acc, [my_state | rem_state]} -> prepend_state(step.({acc, rem_state}), my_state)
      # action
         {input, acc, [my_state | rem_state]} ->
           case fun.(input, acc, my_state) do
             {:halt, acc, new_state} -> {:halt, {acc, [new_state | rem_state]}}
             {:cont, input, acc, new_state} -> prepend_state(step.({input, acc, rem_state}), new_state)
           end
      end
    end, init_state}
  end
end
