defmodule ET do
  def compose([transducer | rest], reducer) do
    compose(rest, transducer.(reducer))
  end
  def compose([], reducer), do: reducer

  def prepend_state({msg, state}, new_state), do: {msg, [new_state | state]}

  def map(transducers \\ [], fun) do
    [fn reducer ->
       fn
         {:fin, state}         -> reducer.({:fin, state})
         {:cont, input, state} -> reducer.({:cont, fun.(input), state})
         :init                 -> reducer.(:init)
       end
     end | transducers]
  end

  def reduce(coll, reducer) do
    do_reduce(coll, reducer.(:init), reducer)
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

  def stateful(transducers \\ [], fun, init_state) do
    [fn reducer ->
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
         :init -> reducer.(:init) |> prepend_state(init_state)
       end
     end | transducers]
  end

  def zip(transducers \\ []) do
    [fn reducer ->
       fn
         # initialization
         :init -> reducer.(:init) |> prepend_state([])
         # collect transducers
         {:cont, input, [my_state | rem_state]} ->
           {:cont, [[input | my_state] | rem_state]}
         # do zip on finish
         {:fin, [transducibles | rem_state]} ->
           zipper =
             fn
               _rfun,  _,  _, {:halt, state} -> state
               _rfun, [], [], {:cont, state} -> state
               rfun, [], t_acc, state ->
                 rfun.(rfun, :lists.reverse(t_acc), [], state)
               rfun, [transducible | rem], t_acc, {:cont, state} ->
                 case Transducible.next(transducible) do
                   :empty -> rfun.(rfun, rem, t_acc, {:cont, state})   
                   {elem, trans} -> rfun.(rfun, rem, [trans | t_acc], reducer.({:cont, elem, state}))
                 end
             end
           result_state = zipper.(zipper, [], transducibles, {:cont, rem_state})
           reducer.({:fin, result_state})
       end
     end | transducers]
  end
end
