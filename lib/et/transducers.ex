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
  A shortcut for at_indices with only a single element.

  """

  @spec at_index(non_neg_integer) :: ET.Transducer.t
  @spec at_index(ET.Transducer.t, non_neg_integer) :: ET.Transducer.t
  def at_index(n), do: at_indices([n])
  def at_index(t, n), do: at_indices(t, [n])
  

  @doc """
  A transducer which takes only the items from indices taken from the transducible. Automatically
  halts if all indices are taken.

  """

  @spec at_indices(ET.Transducer.t, ET.Transducible.t) :: ET.Transducer.t
  @spec at_indices(ET.Transducible.t) :: ET.Transducer.t
  def at_indices(%ET.Transducer{} = trans, indices) do
    compose(trans, at_indices(indices))
  end
  def at_indices(indices) do
    ET.Logic.with_index
    |> new(
      fn r_fun -> r_fun |> init |> cont({indices, HashSet.new}) end,
      fn {elem, index}, reducer, {indices, set} ->
        {result, indices, set} = at_indices_set_test(index, indices, set)
        {{elem, (indices == :done and Transducible.next(set) == :done)}, !result}
        |> reduce(reducer)
        |> cont({indices, set})
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Logic.filter
    |> ET.Logic.destructure
    |> ET.Logic.halt_after
    |> ET.Logic.destructure
  end

  defp at_indices_set_test(index, indices, set) do
    if Set.member?(set, index) do
      {true, indices, Set.delete(set, index)}
    else
      {result, indices, keys} = at_indices_find_element(indices, index)
      put_greater = fn n, set when n > index -> Set.put(set, n)
                       _, set -> set end
      {result, indices, :lists.foldl(put_greater, set, keys)}
    end
  end

  defp at_indices_find_element(:done, _index) do
    {false, :done, []}
  end
  defp at_indices_find_element(indices, index) do
    at_indices_find_element(Transducible.next(indices), index, [])
  end
  defp at_indices_find_element(:done, _index, acc) do
    {false, :done, acc}
  end
  defp at_indices_find_element({index, indices}, index, acc) do
    {true, indices, [index | acc]}
  end
  defp at_indices_find_element({elem, indices}, index, acc) do
    at_indices_find_element(Transducible.next(indices), index, [elem | acc])
  end
  
  @doc """
  A transducer which takes elements and emits chunks of size elements. These chunks default
  to ET.Reducers.list(), but an alternate reducer may be substituted. Elements in each chunk
  are cached until size elements are received and then all are resolved immediately and 
  the result is handed to the main reducer.

  Chunking begins with the first element and by default a new chunk is created every size
  elements, but step can be defined to start chunks more or less frequently.

  If padding is not defined, then incomplete chunks are discarded. If it is defined, then
  elements are applied to incomplete chunks until either all chunks are complete or 
  padding is done and incomplete chunks are processed.

    iex> chunker = ET.Transducers.chunk(2) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [3,4]]

    iex> chunker = ET.Transducers.chunk(2, 1) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [2,3], [3,4], [4,5]]

    iex> chunker = ET.Transducers.chunk(2, [:a,:b,:c]) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [3,4], [5,:a]]

    iex> chunker = ET.Transducers.chunk(2, []) |> ET.Reducers.list()
    iex> ET.reduce(1..5, chunker)
    [[1,2], [3,4], [5]]

  """

  # TODO spec definition for chunk
  def chunk(size), do: chunk(size, size)
  def chunk(%ET.Transducer{} = trans, two) do
    compose(trans, chunk(two))
  end
  def chunk(size, step) when is_integer(size) and is_integer(step) do
    chunk(size, step, nil)
  end
  def chunk(size, reducer) when is_integer(size) and is_function(reducer, 1) do
    chunk(size, size, nil, reducer)
  end
  def chunk(size, padding) when is_integer(size) do
    chunk(size, size, padding)
  end
  def chunk(%ET.Transducer{} = trans, two, three) do
    compose(trans, chunk(two, three))
  end
  def chunk(size, step, reducer) when is_integer(size) and is_integer(step) and is_function(reducer, 1) do
    chunk(size, step, nil, reducer)
  end
  def chunk(size, step, padding) when is_integer(size) and is_integer(step) do
    chunk(size, step, padding, ET.Reducers.list())
  end
  def chunk(%ET.Transducer{} = trans, two, three, four) do
    compose(trans, chunk(two, three, four))
  end
  def chunk(size, step, padding, reducer) do
    inner_reducer =
      ET.Logic.destructure
      |> take(size)
      |> compose(reducer)

    ET.Logic.true_every(step, first: true)
    |> ET.Logic.chunk(inner_reducer, padding)
  end
  def chunk(%ET.Transducer{} = trans, two, three, four, five) do
    compose(trans, chunk(two, three, four, five))
  end


  @doc """
  A transducer which makes a new input whenever the chunking function returns a new value.
  By default, each chunk is reduced into ET.Reducers.list(), but this can be overridden.

  """

  @spec chunk_by() :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t) :: ET.Transducer.t
  @spec chunk_by((term -> term)) :: ET.Transducer.t
  @spec chunk_by((term -> term), ET.reducer) :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec chunk_by(ET.Transducer.t, (term -> term), ET.reducer) :: ET.Transducer.t
  def chunk_by(), do: chunk_by(&(&1))
  def chunk_by(%ET.Transducer{} = trans), do: compose(trans, chunk_by())
  def chunk_by(change_fun), do: chunk_by(change_fun, ET.Reducers.list())
  def chunk_by(%ET.Transducer{} = trans, change_fun), do: compose(trans, chunk_by(change_fun))
  def chunk_by(change_fun, inner_reducer) do
    inner_reducer =
      ET.Logic.ignore(1)
      |> ET.Logic.halt_on
      |> ET.Logic.destructure(2)
      |> compose(inner_reducer)
      
      ET.Logic.change?(change_fun, first: true)
    |> ET.Logic.chunk(inner_reducer, [])
  end
  def chunk_by(%ET.Transducer{} = trans, change_fun, inner_reducer) do
    compose(trans, chunk_by(change_fun, inner_reducer))
  end


  @doc """
  A transducer which takes transducibles and reduces them.

    iex> reducer = ET.Transducers.concat |> ET.Reducers.list
    iex> ET.reduce([1..3, [4, 5]], reducer)
    [1,2,3,4,5]

  """

  @spec concat(ET.Transducer.t) :: ET.Transducer.t
  @spec concat() :: ET.Transducer.t
  def concat(%ET.Transducer{} = trans), do: compose(trans, concat)
  def concat() do
    new(
      fn transducible, reducer ->
        reduce_many(transducible, reducer)
        |> cont
      end
    )
  end

  @doc """
  A transducer which drops a number of elements before continuing.
  Can take a negative value which caches n elements which get dropped
  on :fin.

  """

  def drop(%ET.Transducer{} = trans, n), do: compose(trans, drop(n))
  def drop(n) when n >= 0 do
    new(
      fn r_fun -> r_fun |> init |> cont(n) end,
      fn
        elem, reducer, 0 ->
          {elem, false}
          |> reduce(reducer)
          |> cont(0)
        elem, reducer, n ->
          {elem, true}
          |> reduce(reducer)
          |> cont(n-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Logic.filter
    |> ET.Logic.destructure
  end
  def drop(n) do
    new(
      fn r_fun -> r_fun |> init |> cont({:queue.new, -n}) end,
      fn
        elem, reducer, {queue, 0} ->
          {{:value, val}, queue} = :queue.out(queue)
          val
          |> reduce(reducer)
          |> cont({:queue.in(elem, queue), 0})
        elem, reducer, {queue, n} ->
          cont(reducer, {:queue.in(elem, queue), n-1})
      end,
      fn reducer, _ -> finish(reducer) end
    )
  end
  
  @doc """
  A transducer which does not reduce elements until fun stops returning true.

    iex> reducer = ET.Transducers.drop_while(&(rem(&1, 3) != 0)) |> ET.Reducers.list
    iex> ET.reduce(1..4, reducer)
    [3, 4]

  """

  @spec drop_while(ET.Transducer.t, (term -> boolean)) :: ET.Transducer.t
  @spec drop_while((term -> boolean)) :: ET.Transducer.t
  def drop_while(%ET.Transducer{} = trans, fun) do
    compose(trans, drop_while(fun))
  end
  def drop_while(fun) do
    new(
      fn r_fun -> r_fun |> init |> cont(false) end,
      fn
        elem, reducer, bool when bool == false or bool == nil ->
          result = fun.(elem)
          {elem, result}
          |> reduce(reducer)
          |> cont(!result)
        elem, reducer, bool ->
          {elem, !bool}
          |> reduce(reducer)
          |> cont(true)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Logic.filter
    |> ET.Logic.destructure
  end


  @doc """
  A transducer which will not relay :halt signals until it has recieved a specified
  number of elements. Elements received after a :halt signal is recieved are not
  passed to the reducer. It has no special effect if a :fin signal is received
  before a :halt.

  """
  
  @spec ensure(ET.Transducer.t, non_neg_integer) :: ET.Transducer.t
  @spec ensure(non_neg_integer) :: ET.Transducer.t
  def ensure(%ET.Transducer{} = trans, n), do: compose(trans, ensure(n))
  def ensure(n) do
    new(
      fn r_fun -> r_fun |> init |> cont({:cont, n-1}) end,
      fn
        elem, reducer, {:cont, 0} ->
          elem
          |> reduce(reducer)
          |> cont({:cont, 0})
        
        elem, reducer, {:cont, n} ->
          reducer = reduce(elem, reducer)
          if halted?(reducer) do
            cont_nohalt(reducer, {:halt, n-1})
          else
            cont(reducer, {:cont, n-1})
          end
        
        _, reducer, {:halt, 0} ->
          halt(reducer, {:halt, 0})
        
        _, reducer, {:halt, n} ->
          cont(reducer, {:halt, n-1})
      end,
      fn reducer, _ -> finish(reducer) end
    )
  end
  

  @doc """
  A transducer which only passes elements for which fun(element) is truthy.

  """

  @spec filter(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec filter((term -> term)) :: ET.Transducer.t
  def filter(%ET.Transducer{} = trans, fun), do: compose(trans, filter(fun))
  def filter(fun) do
    ET.Logic.structure(fun)
    |> ET.Logic.negate
    |> ET.Logic.filter
    |> ET.Logic.destructure(2)
  end


  @doc """
  A transducer which filters out when fun.(elem) is falsey and outputs the zero-based
  pre-filter index.

  """

  @spec find_indices((term -> term)) :: ET.Transducer.t
  @spec find_indices(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  def find_indices(fun) do
    ET.Logic.with_index
    |> ET.Logic.structure(fn {elem, _} -> !fun.(elem) end)
    |> ET.Logic.filter
    |> ET.Logic.destructure
    |> ET.Logic.reverse_destructure
  end
  def find_indices(%ET.Transducer{} = trans, fun) do
    compose(trans, find_indices(fun))
  end

  
  @doc """
  A transducer which groups by the result of fun into separate inner_reducers. These reducers
  will be reduced as {fun_value, result} tuples first in the order in which they :halt, or
  in some non-guaranteed order on finish.

  By default, items are reduced into simple lists, but an optional reducing function can be passed
  to override this.

  Additionally, a transducible producing {value, reducing_fun} can be included to give special
  reducers for particular values of fun.(elem).

  """

  #TODO spec definition for group_by
  def group_by(fun), do: group_by(fun, ET.Reducers.list)
  def group_by(%ET.Transducer{} = trans, fun), do: compose(trans, group_by(fun))
  def group_by(fun, r_fun), do: group_by(fun, r_fun, %{})
  def group_by(%ET.Transducer{} = trans, fun, r_fun), do: compose(trans, group_by(fun, r_fun))
  def group_by(fun, r_fun, r_funs) do
    r_fun = compose(ET.Logic.destructure, r_fun)
    r_funs = destructure_r_funs(r_funs)
    
    ET.Logic.structure(fun)
    |> ET.Logic.group_by(r_fun, r_funs)
  end
  def group_by(%ET.Transducer{} = trans, fun, r_fun, r_funs) do
    compose(trans, group_by(fun, r_fun, r_funs))
  end

  defp destructure_r_funs(r_funs) do
    reducer =
      ET.Transducers.map(fn {v,v_fun} -> {v, compose(ET.Logic.destructure, v_fun)} end)
    |> ET.Reducers.list
    
    ET.reduce(r_funs, reducer)
    |> :maps.from_list
  end


  @doc """
  A transducer which sends the supplied element to the reducer between each element.

  """

  def intersperse(term) do
    ET.Logic.structure(fn _ -> true end)
    |> ET.Logic.ignore(1)
    |> ET.Logic.insert_before({{term, nil}, nil})
    |> ET.Logic.destructure(2)
  end
  def intersperse(%ET.Transducer{} = trans, term) do
    compose(trans, intersperse(term))
  end


  @doc """
  A transducer which applies the supplied function and passes the result to the reducer.

    iex> add_one = ET.Transducers.map(&(&1+1) |> ET.Reducers.list()
    iex> ET.reduce(1..3, add_one)
    [2,3,4]

  """
  
  @spec map(ET.Transducer.t, (term -> term)) :: ET.Transducer.t
  @spec map((term -> term)) :: ET.Transducer.t
  def map(%ET.Transducer{} = trans, fun), do: compose(trans, map(fun))
  def map(fun) do
    new(
      fn
        elem, reducer ->
          fun.(elem)
          |> reduce(reducer)
          |> cont
      end
    )
  end


  @doc """
  A transducer which limits the number of elements processed.

    iex> take_two = ET.Transducers.take(2) |> ET.Reducers.list
    iex> ET.reduce(1..3, take_two)
    [1,2]

  """

  @spec take(ET.Transducer.t , non_neg_integer) :: ET.Transducer.t
  @spec take(non_neg_integer) :: ET.Transducer.t
  def take(%ET.Transducer{} = trans, num), do: compose(trans, take(num))
  def take(num) do
    ET.Logic.true_every(num)
    |> ET.Logic.halt_after
    |> ET.Logic.destructure
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
  def zip(%ET.Transducer{} = trans), do: compose(trans, zip())
  def zip() do
    new(
      fn r_fun -> r_fun |> init |> cont([]) end,
      fn collection, reducer, transducibles ->
        reduce_one(collection, reducer)
        |> do_first_zip(transducibles)
      end,
      fn reducer, transducibles ->
        finish_zip([], transducibles, reducer)
      end
    )
  end

  defp do_first_zip({:done, reducer}, transducibles) do
    cont(reducer, transducibles)
  end
  defp do_first_zip({_, {_,{:halt,_}} = reducer}, _) do
    halt(reducer, [])
  end
  defp do_first_zip({continuation, reducer}, transducibles) do
    cont(reducer, [continuation | transducibles])
  end

  defp finish_zip(_, _, {_,{:halt,_}} = reducer) do
    finish(reducer)
  end
  defp finish_zip([], [], reducer), do: finish(reducer)
  defp finish_zip([], t_acc, reducer) do
    finish_zip(:lists.reverse(t_acc), [], reducer)
  end
  defp finish_zip([collection | t_rem], t_acc, reducer) do
    case reduce_one(collection, reducer) do
      {:done, reducer} -> finish_zip(t_rem, t_acc, reducer)
      {continuation, reducer} ->
        finish_zip(t_rem, [continuation | t_acc], reducer)
    end
  end
end
