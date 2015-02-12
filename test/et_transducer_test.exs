defmodule ETTransducerTest do
  use ExUnit.Case, async: true
  import ET.Transducer
  
  defp identity_trans, do: ET.Transducers.map(&(&1))
  

  test "compose transducer with reducer" do
    take_two_list = ET.Transducer.compose(ET.Transducers.take(2), ET.Reducers.list())
    assert ET.reduce([1,2,3,4], take_two_list) == [1,2]
  end

  test "compose two transducers" do
    take_two_inc = ET.Transducer.compose(ET.Transducers.take(2), ET.Transducers.map(fn x -> x+1 end))
    take_two_inc_list = ET.Transducer.compose(take_two_inc, ET.Reducers.list())
    assert ET.reduce([1,2,3,4], take_two_inc_list) == [2,3]
  end

  test "ET.Transducer.cont(reducer_tuple)" do
    assert ET.Transducer.cont({ET.Reducers.list, {:cont, [[]]}}) == {:cont, [[]]}
    assert ET.Transducer.cont({ET.Reducers.list, {:halt, [[]]}}) == {:halt, [[]]}
  end

  test "ET.Transducer.cont(cont_reducer_tuple, state)" do
    assert ET.Transducer.cont({ET.Reducers.list, {:cont, [[]] }}, :foo) ==
           {:cont, [:foo, []]}
  end

  test "ET.Transducer.cont(halt_reducer_tuple, state)" do
    assert ET.Transducer.cont({ET.Reducers.list, {:halt, [[]] }}, :foo) ==
           {:halt, [:foo, []]}
  end

  test "ET.Transducer.cont_nohalt(reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Transducer.cont_nohalt({list_reducer, {:halt, [[]]}}) ==
           {:cont, [[]]}
  end

  test "ET.Transducer.cont_nohalt(reducer, state)" do
    list_reducer = ET.Reducers.list
    assert ET.Transducer.cont_nohalt({list_reducer, {:halt, [[]]}}, :foo) ==
           {:cont, [:foo, []]}
  end

  test "ET.Transducer.finish(reducer_tuple)" do
    list_reducer = ET.Reducers.list
    reducer_tuple = {list_reducer, {:cont, [[2,1]]}}
    assert ET.Transducer.finish(reducer_tuple) ==
           {:fin, [1,2]}
  end

  test "ET.Transducer.halt(reducer_tuple)" do
    assert ET.Transducer.halt({ET.Reducers.list, {:cont, [[]]}}) == {:halt, [[]]}
  end

  test "ET.Transducer.halt(reducer_tuple, state)" do
    assert ET.Transducer.halt({ET.Reducers.list, {:cont, [[]]}}, :foo) ==
           {:halt, [:foo, []]}
  end

  test "ET.Transducer.halted?(reducer)" do
    assert ET.Transducer.halted?({ET.Reducers.list, {:cont, [[]]}}) == false
    assert ET.Transducer.halted?({ET.Reducers.list, {:halt, [[]]}}) == true
  end

  test "ET.Transducer.init(reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Transducer.init(list_reducer) ==
           {list_reducer, {:cont, [[]]}}
  end

  test "ET.Transducer.new(fun)" do
    ET.Transducer.new(
      fn 3, reducer -> halt(reducer)
         n, reducer -> n |> reduce(reducer) |> cont
      end
    )
    |> ET.Reducers.list
    |> new_fun_test
  end

  test "ET.Transducer.new(transducer, fun)" do
    identity_trans
    |> ET.Transducer.new(
         fn 3, reducer -> halt(reducer)
            n, reducer -> n |> reduce(reducer) |> cont
         end
       )
    |> ET.Reducers.list
    |> new_fun_test
  end

  defp new_fun_test(halt_on_3) do
    assert ET.reduce(1..4, halt_on_3) == [1,2]
  end
  
  test "ET.Transducer.new(fun, fun, fun)" do
    ET.Transducer.new(
      fn reducer -> reducer |> init |> cont(2) end,
      fn
        elem, reducer, 0 ->
          elem
          |> reduce(reducer)
          |> halt(0)
        elem, reducer, count ->
          elem
          |> reduce(reducer)
          |> cont(count-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Reducers.list
    |> new_fun_fun_fun_test
  end

  test "ET.Transducer.new(transducer, fun, fun, fun)" do
    identity_trans
    |> ET.Transducer.new(
      fn reducer -> reducer |> init |> cont(2) end,
      fn
        elem, reducer, 0 ->
          elem
          |> reduce(reducer)
          |> halt(0)
        elem, reducer, count ->
          elem
          |> reduce(reducer)
          |> cont(count-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Reducers.list
    |> new_fun_fun_fun_test
  end

  defp new_fun_fun_fun_test(take_three) do
    assert ET.reduce(1..4, take_three) == [1,2,3]
    assert ET.reduce(1..2, take_three) == [1,2]
  end

  test "ET.Transducer.reduce(elem, cont_reducer_tuple)" do
    list_reducer = ET.Reducers.list
    reducer_tuple = {list_reducer, {:cont, [[]]}}
    assert ET.Transducer.reduce(:foo, reducer_tuple) ==
           {list_reducer, {:cont, [[:foo]]}}
  end

  test "ET.Transducer.reduce(elem, halt_reducer_tuple)" do
    list_reducer = ET.Reducers.list
    reducer_tuple = {list_reducer, {:halt, [[]]}}
    assert_raise FunctionClauseError, fn -> ET.Transducer.reduce(:foo, reducer_tuple) end
  end

  test "ET.Transducer.reduce_many(transducible, reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Transducer.reduce_many(1..4, {list_reducer, {:cont, [[]]}}) ==
           {list_reducer, {:cont, [[4,3,2,1]]}}
  end

  test "ET.Transducer.reduce_many(transducible, reducer) early termination" do
    take_two_list_reducer = ET.Transducers.take(2) |> ET.Reducers.list
    assert ET.Transducer.reduce_many(1..4, {take_two_list_reducer, {:cont, [1, []]}}) ==
           {take_two_list_reducer, {:halt, [1, [2,1]]}}
  end

  test "ET.Transducer.reduce_one(transducible, reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Transducer.reduce_one([1,2,3], {list_reducer, {:cont, [[]]}}) ==
           {[2,3], {list_reducer, {:cont, [[1]]}}}
    assert ET.Transducer.reduce_one([], {list_reducer, {:cont, [[]]}}) ==
           {:done, {list_reducer, {:cont, [[]]}}}
  end

end
