defmodule ET.Transducers do
  @moduledoc """
  Provides composable transducer functions.

  Transducers are anonymous functions which take a reducer and return a new reducer
  with the new functionality wrapped around it. Transducers end up having to pass
  signals up and down, transforming, filtering, or doing other fun stuff along the way.

  Transducers should know as little as possible about what is above and below them in
  order to maintain composability.

  ET.Transducer provides a struct to wrap your transducer functions.

  Named transducer functions should optionally take an %ET.Transducer{} struct as their
  first argument to aid in pipelining (all of the transducers in this library do so).

  """
  
  import ET.Transducer

  @doc """
  A transducer which applies the supplied function and passes the result to the reducer.

    iex> add_one = ET.Transducers.map(&(&1+1) |> ET.Reducers.list()
    iex> ET.reduce(1..3, add_one)
    [2,3,4]

  """
  
  @spec map(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec map((term -> term)) :: ET.Transducer.t
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

  @doc """
  A generic stateful transducer with halting capabilities.

  The supplied function should be in the form of:
    element, state -> {:halt, new_state} | {:cont, new_state}
  """

  @type stateful_message :: {:halt, term} | {:cont, term}
  
  @spec stateful(ET.Transducer.t, (term, term -> stateful_message), term) :: ET.Transducer.t
  @spec stateful((term, term -> stateful_message), term) :: ET.Transducer.t
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

  @doc """
  A transducer which limits the number of elements processed.

    iex> take_two = ET.Transducers.take(2) |> ET.Reducers.list
    iex> ET.reduce(1..3, take_two)
    [1,2]

  """
  
  @spec take(ET.Transducer.t , non_neg_integer) :: ET.Transducer.t
  @spec take(non_neg_integer) :: ET.Transducer.t
  def take(transducers \\ %ET.Transducer{}, num) do
    stateful(transducers,
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, num)
  end

  @doc """
  A transducers which takes several transducers and interleaves their
  contents.

  Zip sends the first element of each transducible as soon as it receives it,
  but all remaining elements are cached until a signal to finish is received
  at which point it recurses over the remaining elements. If it ever receives
  a signal to halt from below, it clears its cache.

    iex> ET.reduce([1..4, ["a", "b"]], ET.Transducers.zip |> ET.Reducers.list)
    [1, "a", 2, "b", 3, 4]

    iex> zip_then_take_three = ET.Transducers.zip |> ET.Transducers.take(3) |> ET.Reducers.list
    iex> ET.reduce([1..4, ["a", "b"]], zip_then_take_three)
    [1, "a", 2]

  """
  
  @spec zip(ET.Transducer.t) :: ET.Transducer.t
  @spec zip() :: ET.Transducer.t
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
