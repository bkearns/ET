defmodule ET.Transducers do
  @moduledoc """
  Provides composable transducer functions.

  Transducers are anonymous functions which take a reducer and return a new
  reducer with the new functionality wrapped around it. Transducers end up
  having to pass
  signals up and down, transforming, filtering, or doing other fun stuff along
  the way.

  Transducers should know as little as possible about what is above and below
  them in order to maintain composability.

  ET.Transducer provides a struct to wrap your transducer functions.

  Named transducer functions should optionally take an %ET.Transducer{} struct
  as their first argument to aid in pipelining (all of the transducers in this
  library do so).

  """

  import ET.Transducer

  @doc """
  A shortcut for at_indices with only a single element.

  """

  def at_index(n), do: at_indices([n])
  def at_index(t, n), do: at_indices(t, [n])


  @doc """
  A transducer which takes only the items from indices taken from the
  transducible. Automatically done if all indices are taken.

  """

  def at_indices(%ET.Transducer{} = trans, indices) do
    compose(trans, at_indices(indices))
  end
  def at_indices(indices) do
    ET.Wrapped.with_index
    |> new(
      fn r_fun -> r_fun |> init |> cont({indices, HashSet.new}) end,
      fn {elem, index}, reducer, {indices, set} ->
        {result, indices, set} = at_indices_set_test(index, indices, set)
        {{elem,(indices == :done and Set.size(set) == 0)}, !result}
        |> reduce_elem(reducer)
        |> cont({indices, set})
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Wrapped.filter
    |> ET.Wrapped.unwrap
    |> ET.Wrapped.halt_after
    |> ET.Wrapped.unwrap
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
    at_indices_find_element(ET.next(indices), index, [])
  end
  defp at_indices_find_element({:done, nil}, _index, acc) do
    {false, :done, acc}
  end
  defp at_indices_find_element({:suspended, index, indices}, index, acc) do
    {true, indices, [index | acc]}
  end
  defp at_indices_find_element({:suspended, elem, indices}, index, acc) do
    at_indices_find_element(ET.next(indices), index, [elem | acc])
  end


  @doc """
  A transducer which takes elements and emits chunks of size elements. These
  chunks default to ET.Reducers.list(), but an alternate reducer may be
  substituted. Elements in each chunk are cached until size elements are
  received and then all are resolved immediately and the result is handed to the
  main reducer.

  Chunking begins with the first element and by default a new chunk is created
  every size elements, but step can be defined to start chunks more or less
  frequently.

  If padding is not defined, then incomplete chunks are discarded. If it is
  defined, then elements are applied to incomplete chunks until either all
  chunks are complete or padding is done and incomplete chunks are processed.

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
  def chunk(size, step, reducer) when
  is_integer(size) and is_integer(step) and is_function(reducer, 2) do
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
      ET.Wrapped.unwrap
      |> take(size)
      |> compose(reducer)

    ET.Wrapped.true_every(step, first: true)
    |> ET.Wrapped.chunk(inner_reducer, padding)
  end
  def chunk(%ET.Transducer{} = trans, two, three, four, five) do
    compose(trans, chunk(two, three, four, five))
  end


  @doc """
  A transducer which makes a new input whenever the chunking function returns a
  new value. By default, each chunk is reduced into ET.Reducers.list(), but this
  can be overridden.

  """

  def chunk_by(), do: chunk_by(&(&1))
  def chunk_by(%ET.Transducer{} = trans), do: compose(trans, chunk_by())
  def chunk_by(change_fun), do: chunk_by(change_fun, ET.Reducers.list())
  def chunk_by(%ET.Transducer{} = trans, change_fun) do
    compose(trans, chunk_by(change_fun))
  end
  def chunk_by(change_fun, inner_reducer) do
    inner_reducer =
      ET.Wrapped.ignore(1)
      |> ET.Wrapped.halt_on
      |> ET.Wrapped.unwrap(2)
      |> compose(inner_reducer)

      ET.Wrapped.change?(change_fun, first: true)
    |> ET.Wrapped.chunk(inner_reducer, [])
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
          |> reduce_elem(reducer)
          |> cont(0)
        elem, reducer, n ->
          {elem, true}
          |> reduce_elem(reducer)
          |> cont(n-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Wrapped.filter
    |> ET.Wrapped.unwrap
  end
  def drop(n) do
    new(
      fn r_fun -> r_fun |> init |> cont({:queue.new, -n}) end,
      fn
        elem, reducer, {queue, 0} ->
          {{:value, val}, queue} = :queue.out(queue)
          val
          |> reduce_elem(reducer)
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

  def drop_while(%ET.Transducer{} = trans, fun) do
    compose(trans, drop_while(fun))
  end
  def drop_while(fun) do
    new(
      fn r_fun -> r_fun |> init |> cont(false) end,
      fn
        elem, reducer, bool when bool in [false, nil] ->
          result = fun.(elem)
          {elem, result}
          |> reduce_elem(reducer)
          |> cont(!result)
        elem, reducer, bool ->
          {elem, !bool}
          |> reduce_elem(reducer)
          |> cont(true)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Wrapped.filter
    |> ET.Wrapped.unwrap
  end


  @doc """
  A transducer which will not relay :halt signals until it has recieved a
  specified number of elements. Elements received after a :halt signal is
  recieved are not passed to the reducer. It has no special effect if a :fin
  signal is received before a :halt.

  """

  def ensure(%ET.Transducer{} = trans, n), do: compose(trans, ensure(n))
  def ensure(n) do
    new(
      fn r_fun -> r_fun |> init |> cont({:cont, n-1}) end,
      fn
        elem, reducer, {:cont, 0} ->
          elem
          |> reduce_elem(reducer)
          |> cont({:cont, 0})

        elem, reducer, {:cont, n} ->
          reducer = reduce_elem(elem, reducer)
          if halted?(reducer) do
            reducer |> cont_no_halt({:halt, n-1})
          else
            reducer |> cont({:cont, n-1})
          end

        _, reducer, {:halt, 0} ->
          reducer |> halt({:halt, 0})

        _, reducer, {:halt, n} ->
          reducer |> cont({:halt, n-1})
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
    ET.Wrapped.wrap(fun)
    |> ET.Wrapped.negate
    |> ET.Wrapped.filter
    |> ET.Wrapped.unwrap(2)
  end


  @doc """
  A transducer which filters out when fun.(elem) is falsey and outputs the
  zero-based pre-filter index.

  """

  def find_indices(fun) do
    ET.Wrapped.with_index
    |> ET.Wrapped.wrap(fn {elem, _} -> !fun.(elem) end)
    |> ET.Wrapped.filter
    |> ET.Wrapped.unwrap
    |> ET.Wrapped.reverse_unwrap
  end
  def find_indices(%ET.Transducer{} = trans, fun) do
    compose(trans, find_indices(fun))
  end


  @doc """
  A transducer which groups by the result of fun into separate inner_reducers.
  These reducers will be reduced as {fun_value, result} tuples first in the
  order in which they :halt, or in some non-guaranteed order on finish.

  By default, items are reduced into simple lists, but an optional reducing
  function can be passed to override this.

  Additionally, a transducible producing {value, reducing_fun} can be included
  to give special reducers for particular values of fun.(elem).

  """

  def group_by(fun), do: group_by(fun, ET.Reducers.list)
  def group_by(%ET.Transducer{} = trans, fun), do: compose(trans, group_by(fun))
  def group_by(fun, r_fun), do: group_by(fun, r_fun, %{})
  def group_by(%ET.Transducer{} = trans, fun, r_fun) do
    compose(trans, group_by(fun, r_fun))
  end
  def group_by(fun, r_fun, r_funs) do
    r_fun = compose(ET.Wrapped.unwrap, r_fun)
    r_funs = unwrap_r_funs(r_funs)

    ET.Wrapped.wrap(fun)
    |> ET.Wrapped.group_by(r_fun, r_funs)
  end
  def group_by(%ET.Transducer{} = trans, fun, r_fun, r_funs) do
    compose(trans, group_by(fun, r_fun, r_funs))
  end

  defp unwrap_r_funs(r_funs) do
    reducer =
      ET.Transducers.map(fn {v,v_fun} ->
        {v, compose(ET.Wrapped.unwrap, v_fun)}
      end)
    |> ET.Reducers.list

    ET.reduce(r_funs, reducer)
    |> :maps.from_list
  end


  @doc """
  A transducer which sends the supplied element to the reducer between each
  element.

  """

  def intersperse(term) do
    ET.Wrapped.wrap(fn _ -> true end)
    |> ET.Wrapped.ignore(1)
    |> ET.Wrapped.insert_before({{term, nil}, nil})
    |> ET.Wrapped.unwrap(2)
  end
  def intersperse(%ET.Transducer{} = trans, term) do
    compose(trans, intersperse(term))
  end


  @doc """
  A transducer which applies the supplied function and passes the result to the
  reducer.

    iex> add_one = ET.Transducers.map(&(&1+1) |> ET.Reducers.list()
    iex> ET.reduce(1..3, add_one)
    [2,3,4]

  """

  def map(%ET.Transducer{} = trans, fun), do: compose(trans, map(fun))
  def map(fun) do
    new(
      fn
        elem, reducer ->
          fun.(elem)
          |> reduce_elem(reducer)
          |> cont
      end
    )
  end


  @doc """
  Reverses the elements. To do so, it must cache all elements and send them
  on :fin.

  """

  def reverse() do
    new(
      fn r_fun -> r_fun |> init |> cont([]) end,
      fn
        elem, reducer, acc ->
          reducer |> cont([elem | acc])
      end,
      fn
        reducer, acc ->
          acc |> reduce_many(reducer) |> finish
      end
    )
  end
  def reverse(%ET.Transducer{} = trans), do: compose(trans, reverse)


  @doc """
  A transducer which calls fun.(elem, acc) and emits acc and uses it for the
  next element.

  """

  def scan(acc, fun) do
    ET.Wrapped.unfold(acc, fn e, a -> r = fun.(e,a); {r,r} end)
    |> ET.Wrapped.reverse_unwrap
  end
  def scan(%ET.Transducer{} = trans, acc, fun) do
    compose(trans, scan(acc, fun))
  end


  @doc """
  A transducer which caches elements and then emits them in a random order on
  :fin.

  """

  def shuffle() do
    ET.Wrapped.wrap(fn _ -> :random.uniform end)
    |> ET.Wrapped.sort_by
    |> ET.Wrapped.unwrap
  end
  def shuffle(%ET.Transducer{} = trans), do: compose(trans, shuffle)


  @doc """
  A transducer which takes count elements starting at 0-based index start.

  """


  def slice(%Range{first: first, last: last}) do
    first_slice(first)
    |> last_slice(last)
  end
  def slice(%ET.Transducer{} = trans, range) do
    compose(trans, slice(range))
  end
  def slice(start, count) when start >= 0 do
    drop(start)
    |> take(count)
  end
  def slice(start, count) do
    take(start)
    |> take(count)
  end
  def slice(%ET.Transducer{} = trans, start, count) do
    compose(trans, slice(start, count))
  end

  defp first_slice(n) when n >= 0, do: drop(n)
  defp first_slice(n), do: take(n)

  defp last_slice(first, n) when n >= 0 do
    ET.Wrapped.with_index
    |> compose(first)
    |> take_while(&(elem(&1,1) <= n))
    |> ET.Wrapped.unwrap
  end
  defp last_slice(first, n), do: compose(first, drop(n+1))

  @doc """
  A transducer which sorts elements.
  Requires cacheing all elements until :fin is received.

  """

  def sort() do
    sort_by(&(&1))
  end
  def sort(%ET.Transducer{} = trans), do: compose(trans, sort)


  @doc """
  A transducer which sorts elements on the result of fun.(elem).
  Requires cacheing all elements until :fin is received.

  """

  def sort_by(map_fun), do: sort_by(map_fun, &<=/2)
  def sort_by(%ET.Transducer{} = trans, map_fun) do
    compose(trans, sort_by(map_fun))
  end
  def sort_by(map_fun, sort_fun) do
    ET.Wrapped.wrap(map_fun)
    |> ET.Wrapped.sort_by(sort_fun)
    |> ET.Wrapped.unwrap
  end
  def sort_by(%ET.Transducer{} = trans, map_fun, sort_fun) do
    compose(trans, sort_by(map_fun, sort_fun))
  end


  @doc """
  A transducer which splits after n elements. Each split is reduced to an inner
  reducing function which defaults to ET.Reducers.list.

  """

  def split(n), do: split(n, ET.Reducers.list)
  def split(%ET.Transducer{} = trans, n) do
    compose(trans, split(n))
  end
  def split(n, r_fun), do: split(n, r_fun, r_fun)
  def split(%ET.Transducer{} = trans, n, r_fun) do
    compose(trans, split(n, r_fun))
  end
  def split(n, first_r_fun, second_r_fun) do
    first_r_fun = compose(ET.Wrapped.unwrap, first_r_fun)
    second_r_fun = compose(ET.Wrapped.unwrap, second_r_fun)

    ET.Wrapped.with_index
    |> split_while(&(elem(&1,1) < n), first_r_fun, second_r_fun)
  end
  def split(%ET.Transducer{} = trans, n, first_r_fun, second_r_fun) do
    compose(trans, split(n, first_r_fun, second_r_fun))
  end


  @doc """
  A transducer which collects elements into one group while fun.(elem) returns
  truthy and then sends everything else into a second group. Each group is
  reduced independently to the optional r_fun(s), or into lists if not specified.

  """

  def split_while(fun), do: split_while(fun, ET.Reducers.list)
  def split_while(%ET.Transducer{} = trans, fun) do
    compose(trans, split_while(fun))
  end
  def split_while(fun, r_fun), do: split_while(fun, r_fun, r_fun)
  def split_while(%ET.Transducer{} = trans, fun, r_fun) do
    compose(trans, split_while(fun, r_fun))
  end
  def split_while(fun, first_r_fun, second_r_fun) do
    new(
      fn r_fun ->
        r_fun |> init
        |> cont({init(first_r_fun), init(second_r_fun)})
      end,
      fn
        elem, reducer, {nil, second_reducer} ->
          second_split(elem, reducer, second_reducer)
        elem, reducer, {first_reducer, second_reducer} ->
          if fun.(elem) do
            first_split(elem, reducer, first_reducer, second_reducer)
          else
            reducer = finish_split(first_reducer, reducer)
            second_split(elem, reducer, second_reducer)
          end
      end,
      fn reducer, {first_reducer, second_reducer} ->
        reducer = finish_split(first_reducer, reducer)
        reducer = finish_split(second_reducer, reducer)
        finish(reducer)
      end
    )
  end
  def split_while(%ET.Transducer{} = trans, fun, first_r_fun, second_r_fun) do
    compose(trans, split_while(fun, first_r_fun, second_r_fun))
  end

  defp first_split(_, reducer, {_,{:halt,_}} = first_reducer, second_reducer) do
    reducer |> cont({first_reducer, second_reducer})
  end
  defp first_split(elem, reducer, first_reducer, second_reducer) do
    first_reducer = elem |> reduce_elem(first_reducer)
    if halted? first_reducer do
      first_reducer |> finish |> reduce_elem(reducer)
      |> cont({first_reducer, second_reducer})
    else
      reducer |> cont({first_reducer, second_reducer})
    end
  end

  defp second_split(_, {_,{:halt,_}} = reducer, second_reducer) do
    finish(second_reducer)
    reducer |> halt({nil, nil})
  end
  defp second_split(elem, reducer, second_reducer) do
    second_reducer = elem |> reduce_elem(second_reducer)
    if halted? second_reducer do
      second_result = second_reducer |> finish
      unless halted?(reducer), do: reducer = second_result |> reduce_elem(reducer)
      reducer |> halt({nil, nil})
    else
      reducer |> cont({nil, second_reducer})
    end
  end

  defp finish_split(inner_reducer, reducer) do
    if inner_reducer && !halted?(inner_reducer) do
      result = finish(inner_reducer)
      unless halted?(reducer), do: reducer = result |> reduce_elem(reducer)
    end
    reducer
  end


  @doc """
  A transducer which limits the number of elements processed.

    iex> take_two = ET.Transducers.take(2) |> ET.Reducers.list
    iex> ET.reduce(1..3, take_two)
    [1,2]

  """

  def take(%ET.Transducer{} = trans, num), do: compose(trans, take(num))
  def take(n) when n >= 0 do
    ET.Wrapped.true_every(n)
    |> ET.Wrapped.halt_after
    |> ET.Wrapped.unwrap
  end
  def take(n) do
    new(
      fn r_fun -> r_fun |> init |> cont({:queue.new, -n}) end,
      fn
        elem, reducer, {queue, 0} ->
          {_, queue} = :queue.out(queue)
          reducer |> cont({:queue.in(elem, queue), 0})
        elem, reducer, {queue, n} ->
          reducer |> cont({:queue.in(elem, queue), n-1})
      end,
      fn reducer, {queue, _} ->
        queue |> :queue.to_list |> reduce_many(reducer) |> finish
      end
    )
  end


  @doc """
  A transducer which emits the first element and every nth element after.

  """

  def take_every(n) do
    ET.Wrapped.true_every(n, first: true)
    |> ET.Wrapped.negate
    |> ET.Wrapped.filter
    |> ET.Wrapped.unwrap(2)
  end
  def take_every(%ET.Transducer{} = trans, n) do
    compose(trans, take_every(n))
  end


  @doc """
  A transducer which halts immediately if fun.(elem) returns falsey.

  """

  def take_while(fun) do
    ET.Wrapped.wrap(fun)
    |> ET.Wrapped.negate
    |> ET.Wrapped.halt_on
    |> ET.Wrapped.unwrap(2)
  end
  def take_while(%ET.Transducer{} = trans, fun) do
    compose(trans, take_while(fun))
  end


  @doc """
  A transducer which only emits the first occurrence of each unique element.

  """

  def uniq() do
    ET.Wrapped.wrap(&(&1))
    |> ET.Wrapped.unique_by
    |> ET.Wrapped.unwrap
  end
  def uniq(%ET.Transducer{} = trans), do: compose(trans, uniq)


  @doc """
  A transducer which takes several transducers and interleaves their
  contents.

  Zip sends the first element of each transducible as soon as it receives it,
  but all remaining elements are cached until a signal to finish is received
  at which point it recurses over the remaining elements. If it ever receives
  a signal :halt from below, it clears its cache.

    iex> ET.reduce([1..4, ["a", "b"]], ET.Transducers.zip |> ET.Reducers.list)
    [1, "a", 2, "b", 3, 4]

    iex> zip_then_take_three = ET.Transducers.zip |> ET.Transducers.take(3) |> ET.Reducers.list
    iex> ET.reduce([1..4, ["a", "b"]], zip_then_take_three)
    [1, "a", 2]

  """

  def zip() do
    ET.Wrapped.zip
    |> ET.Wrapped.unwrap
  end
  def zip(%ET.Transducer{} = trans), do: compose(trans, zip)
end
