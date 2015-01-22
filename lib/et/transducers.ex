defmodule ET.Transducers do
  import ET
  import ET.Transducer
  
  def map(%ET.Transducer{} = trans, fun), do: combine(trans, map(fun))
  def map(fun) do
    %ET.Transducer{elements:
      [fn reducer ->
         fn
           :init                 -> reducer.(:init)
           {:cont, input, state} -> reducer.({:cont, fun.(input), state})
           {:fin, state}         -> reducer.({:fin, state})
         end
       end]}
  end

  def stateful(%ET.Transducer{} = trans, fun, init_state), do: combine(trans, stateful(fun, init_state))
  def stateful(fun, init_state) do
    %ET.Transducer{elements: 
      [fn reducer ->
         fn
           # initialization
           :init -> reducer.(:init) |> prepend_state(init_state)
           # action
           {:cont, input, [my_state | rem_state]} ->
             case fun.(input, my_state) do
               {:halt, new_state} -> {:halt, [new_state | rem_state]}
               {:cont, input, new_state} ->
                 reducer.({:cont, input, rem_state})
                 |> prepend_state(new_state)
             end
           # completion
           {:fin, [_my_state | rem_state]} ->
             reducer.({:fin, rem_state})
         end
       end]}
  end

  def take(transducers \\ %ET.Transducer{}, num) do
    stateful(transducers,
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, num)
  end

  def zip(%ET.Transducer{} = trans), do: combine(trans, zip())
  def zip() do
    %ET.Transducer{elements:
      [fn reducer ->
        fn
          # initialization
          :init -> reducer.(:init) |> prepend_state([])
                   
          # collect transducers passing first element of each
          {:cont, input, [my_state | rem_state]} ->
            case Transducible.next(input) do
              :done -> {:cont, [my_state | rem_state]}
              {elem, rem} ->
                case reducer.({:cont, elem, rem_state}) do
                  {:halt, state} -> prepend_state({:halt, state}, [])
                  {:cont, state} -> prepend_state({:cont, state}, [rem | my_state])
                end
            end
            
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
                    :done -> rfun.(rfun, rem, t_acc, {:cont, state})   
                    {elem, trans} -> rfun.(rfun, rem, [trans | t_acc], reducer.({:cont, elem, state}))
                  end
              end
            result_state = zipper.(zipper, [], transducibles, {:cont, rem_state})
            reducer.({:fin, result_state})
        end
      end]}
  end

end
