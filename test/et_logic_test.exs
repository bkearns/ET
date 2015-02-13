defmodule ETLogicTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Logic.change?()" do
    ET.Logic.change?
    |> ET.Reducers.list
    |> change_test
  end

  test "ET.Logic.change?(transducer)" do
    identity_trans
    |> ET.Logic.change?
    |> ET.Reducers.list
    |> change_test
  end

  defp change_test(reducer) do
    assert ET.reduce([1,1,1,2,3], reducer) ==
           [{1, false}, {1, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.change?(first: true)" do
    ET.Logic.change?(first: true)
    |> ET.Reducers.list
    |> change_first_true_test
  end

  test "ET.Logic.change?(transducer, first: true)" do
    identity_trans
    |> ET.Logic.change?(first: true)
    |> ET.Reducers.list
    |> change_first_true_test
  end

  defp change_first_true_test(reducer) do
    assert ET.reduce([1,1,1,2,3], reducer) ==
           [{1, true}, {1, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.change?(change_check)" do
    ET.Logic.change?(&(rem(&1, 2)))
    |> ET.Reducers.list
    |> change_change_check_test
  end

  test "ET.Logic.change?(transducer, change_check)" do
    identity_trans
    |> ET.Logic.change?(&(rem(&1, 2)))
    |> ET.Reducers.list
    |> change_change_check_test
  end

  defp change_change_check_test(reducer) do
    assert ET.reduce([1,3,1,2,3], reducer) ==
           [{1, false}, {3, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.change?(change_check, first: true)" do
    ET.Logic.change?(&(rem(&1, 2)), first: true)
    |> ET.Reducers.list
    |> change_change_check_first_true_test
  end

  test "ET.Logic.change?(transducer, change_check, first: true)" do
    identity_trans
    |> ET.Logic.change?(&(rem(&1, 2)), first: true)
    |> ET.Reducers.list
    |> change_change_check_first_true_test
  end

  defp change_change_check_first_true_test(reducer) do
    assert ET.reduce([1,3,1,2,3], reducer) ==
           [{1, true}, {3, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.chunk(inner_reducer)" do
    ET.Logic.chunk(ET.Transducers.take(2) |> ET.Reducers.list)
    |> ET.Reducers.list
    |> chunk_inner_reducer_test
  end

  test "ET.Logic.chunk(transducer, inner_reducer)" do
    identity_trans
    |> ET.Logic.chunk(ET.Transducers.take(2) |> ET.Reducers.list)
    |> ET.Reducers.list
    |> chunk_inner_reducer_test
  end

  defp chunk_inner_reducer_test(reducer) do
    ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], reducer)
    [[{2, true}, {3, false}]]
  end

  test "ET.Logic.chunk(inner_reducer, padding)" do
    ET.Logic.chunk((ET.Transducers.take(2) |> ET.Reducers.list), [])
    |> ET.Reducers.list
    |> chunk_inner_reducer_padding_test
  end

  test "ET.Logic.chunk(transducer, inner_reducer, padding)" do
    identity_trans
    |> ET.Logic.chunk((ET.Transducers.take(2) |> ET.Reducers.list), [])
    |> ET.Reducers.list
    |> chunk_inner_reducer_padding_test
  end

  defp chunk_inner_reducer_padding_test(reducer) do
    assert ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], reducer) ==
    [[{2, true}, {3, false}], [{4, true}]]
  end

  test "ET.Logic.chunk(inner_reducer, padding) with extra padding" do
    reducer =
      ET.Logic.chunk((ET.Transducers.take(2) |> ET.Reducers.list), 5..8)
      |> ET.Reducers.list
      
    assert ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], reducer) == 
    [[{2, true}, {3, false}], [{4, true}, {5, nil}]]    
  end
  
  test "ET.Logic.destructure()" do
    ET.Logic.destructure
    |> ET.Reducers.list
    |> destructure_test
  end

  test "ET.Logic.destructure(transducer)" do
    identity_trans
    |> ET.Logic.destructure
    |> ET.Reducers.list
    |> destructure_test
  end

  defp destructure_test(reducer) do
    assert ET.reduce([{1, true}, {2, false}, {3, true}], reducer) ==
           [1,2,3]
  end

  test "ET.Logic.destructure(n)" do
    ET.Logic.destructure(2)
    |> ET.Reducers.list
    |> destructure_n_test
  end

  test "ET.Logic.destructure(transducer, n)" do
    identity_trans
    |> ET.Logic.destructure(2)
    |> ET.Reducers.list
    |> destructure_n_test
  end

  defp destructure_n_test(reducer) do
    assert ET.reduce([{{1, true}, false}, {{2, false}, false}, {{3, true}, true}], reducer) ==
           [1,2,3]
  end

  test "ET.Logic.filter()" do
    ET.Logic.filter
    |> ET.Reducers.list
    |> filter_test
  end

  test "ET.Logic.filter(transducer)" do
    identity_trans
    |> ET.Logic.filter
    |> ET.Reducers.list
    |> filter_test
  end

  defp filter_test(reducer) do
    assert ET.reduce([{1, true}, {2, true}, {3, false}, {4, true}], reducer) ==
           [{3, false}]
  end

  test "ET.Logic.group_by(reducer, reducers)" do
    ET.Logic.group_by(ET.Reducers.count, %{2 => ET.Logic.destructure |> ET.Reducers.list})
    |> ET.Reducers.map
    |> group_by_reducer_reducers_test
  end

  test "ET.Logic.group_by(transducer, reducer, reducers)" do
    identity_trans
    |> ET.Logic.group_by(ET.Reducers.count, %{2 => ET.Logic.destructure |> ET.Reducers.list})
    |> ET.Reducers.map
    |> group_by_reducer_reducers_test
  end

  defp group_by_reducer_reducers_test(count_except_two) do
    assert ET.reduce([{false, 1}, {false, 3}, {:foo, 2}, {false, 1}, {:bar, 2}], count_except_two) ==
           %{1 => 2, 2 => [:foo, :bar], 3 => 1}
  end

  test "ET.Logic.group_by(reducer)" do
    ET.Logic.group_by(ET.Logic.destructure |> ET.Reducers.list)
    |> ET.Reducers.map
    |> group_by_reducer_test
  end

  test "ET.Logic.group_by(transducer, reducer)" do
    identity_trans
    |> ET.Logic.group_by(ET.Logic.destructure |> ET.Reducers.list)
    |> ET.Reducers.map
    |> group_by_reducer_test
  end

  defp group_by_reducer_test(reducer) do
    assert ET.reduce([{1,1}, {2,2}, {3,1}, {4,2}], reducer) ==
    %{1 => [1,3], 2 => [2,4]}
  end

  test "ET.Logic.group_by doesn't send items to halted reducer" do
    r_fun =
      ET.Logic.structure(&(&1))
      |> ET.Logic.group_by(ET.Transducers.take(1)
                           |> ET.Logic.destructure
                           |> ET.Reducers.list)
      |> ET.Transducers.take(1)
      |> ET.Logic.destructure
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) == [1]
  end

  test "ET.Logic.halt_after()" do
    ET.Logic.halt_after
    |> ET.Reducers.list
    |> halt_after_test
  end

  test "ET.Logic.halt_after(transducer)" do
    identity_trans
    |> ET.Logic.halt_after
    |> ET.Reducers.list
    |> halt_after_test
  end

  defp halt_after_test(reducer) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], reducer) ==
    [{1, false}, {2, false}, {3, true}]
  end

  test "ET.Logic.halt_on()" do
    ET.Logic.halt_on
    |> ET.Reducers.list
    |> halt_on_test
  end

  test "ET.Logic.halt_on(transducer)" do
    identity_trans
    |> ET.Logic.halt_on
    |> ET.Reducers.list
    |> halt_on_test
  end

  defp halt_on_test(reducer) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], reducer) ==
    [{1, false}, {2, false}]
  end

  test "ET.Logic.ignore(n)" do
    ET.Logic.ignore(2)
    |> ET.Reducers.list
    |> ignore_n_test
  end

  test "ET.Logic.ignore(transducer, n)" do
    identity_trans
    |> ET.Logic.ignore(2)
    |> ET.Reducers.list
    |> ignore_n_test
  end

  def ignore_n_test(ignore_two) do
    assert ET.reduce([a: true, b: false, c: true, d: true] ,ignore_two) ==
           [{{:a, true}, false}, {{:b, false}, false}, {{:c, true}, false}, {{:d, true}, true}]
  end

  test "ET.Logic.insert_before(term)" do
    ET.Logic.insert_before({:foo, :bar})
    |> ET.Reducers.list
    |> insert_before_term_test
  end

  test "ET.Logic.insert_before(transducer, term)" do
    identity_trans
    |> ET.Logic.insert_before({:foo, :bar})
    |> ET.Reducers.list
    |> insert_before_term_test
  end

  defp insert_before_term_test(foo_bar_inserter) do
    assert ET.reduce([{1,true}, {2,false}, {3,true}], foo_bar_inserter) ==
           [{:foo, :bar}, {1,true}, {2,false}, {:foo, :bar}, {3,true}]
  end

  test "ET.Logic.in_collection(transducible)" do
    ET.Logic.in_collection([2, 1, 5])
    |> ET.Reducers.list
    |> logic_in_collection_transducible_test
  end

  test "ET.Logic.in_collection(transducer, transducible)" do
    identity_trans
    |> ET.Logic.in_collection([2, 1, 5])
    |> ET.Reducers.list
    |> logic_in_collection_transducible_test
  end

  defp logic_in_collection_transducible_test(reducer) do
    assert ET.reduce([{false, 1}, {true, 3}, {false, 4}, {true, 1}], reducer) ==
           [{{false, 1},true}, {{true,3},false}, {{false,4},false}, {{true, 1},true}]
  end

  test "ET.Logic.in_collection(transducible, one_for_one: true)" do
    ET.Logic.in_collection([2, 1, 5], one_for_one: true)
    |> ET.Reducers.list
    |> logic_in_collection_transducible_one_for_one_test
  end

  test "ET.Logic.in_collection(transducer, transducible, one_for_one: true)" do
    identity_trans
    |> ET.Logic.in_collection([2, 1, 5], one_for_one: true)
    |> ET.Reducers.list
    |> logic_in_collection_transducible_one_for_one_test
  end

  defp logic_in_collection_transducible_one_for_one_test(reducer) do
    assert ET.reduce([{false, 1}, {true, 3}, {false, 4}, {true, 1}], reducer) ==
           [{{false, 1},true}, {{true,3},false}, {{false,4},false}, {{true, 1},false}]
  end

  test "ET.Logic.in_collection(transducible, one_for_one: true) when transducible is empty" do
    reducer =
      ET.Logic.in_collection([1], one_for_one: true)
      |> ET.Reducers.list

    assert ET.reduce([{false, 1}, {true, 1}], reducer) ==
           [{{false, 1}, true}, {{true, 1}, nil}]
  end

  test "ET.Logic.negate()" do
    ET.Logic.negate
    |> ET.Reducers.list
    |> negate_test
  end

  test "ET.Logic.negate(transducer)" do
    identity_trans
    |> ET.Logic.negate
    |> ET.Reducers.list
    |> negate_test
  end

  defp negate_test(reducer) do
    assert ET.reduce([{1, true}, {2, 2}, {3, false}, {4, nil}], reducer) ==
           [{{1,true},false}, {{2,2},false}, {{3,false},true}, {{4,nil},true}]
  end

  test "ET.Logic.reverse_destructure()" do
    ET.Logic.reverse_destructure
    |> ET.Reducers.list
    |> reverse_destructure_test
  end

  test "ET.Logic.reverse_destructure(transducer)" do
    identity_trans
    |> ET.Logic.reverse_destructure
    |> ET.Reducers.list
    |> reverse_destructure_test
  end

  defp reverse_destructure_test(reducer) do
    assert ET.reduce([{1, true}, {2, 2}, {3, false}, {4, nil}], reducer) ==
           [true, 2, false, nil]
  end

  test "ET.Logic.structure(fun)" do
    ET.Logic.structure(&(rem(&1,3)))
    |> ET.Reducers.list
    |> structure_test
  end
  
  test "ET.Logic.structure(transducer, fun)" do
    identity_trans
    |> ET.Logic.structure(&(rem(&1,3)))
    |> ET.Reducers.list
    |> structure_test
  end

  defp structure_test(reducer) do
    assert ET.reduce(1..4, reducer) ==
           [{1,1},{2,2},{3,0},{4,1}] 
  end
  
  
  test "ET.Logic.true_every(n)" do
    ET.Logic.true_every(2)
    |> ET.Reducers.list
    |> true_every_n_test
  end

  test "ET.Logic.true_every(n, transducer)" do
    identity_trans
    |> ET.Logic.true_every(2)
    |> ET.Reducers.list
    |> true_every_n_test
  end

  defp true_every_n_test(reducer) do
    assert ET.reduce(1..4, reducer) ==
           [{1, false}, {2, true}, {3, false}, {4, true}]
  end

  test "ET.Logic.true_every(n, first: true)" do
    ET.Logic.true_every(2, first: true)
    |> ET.Reducers.list
    |> true_every_n_first_true_test
  end

  test "ET.Logic.true_every(transducer, n, first: true)" do
    identity_trans
    |> ET.Logic.true_every(2, first: true)
    |> ET.Reducers.list
    |> true_every_n_first_true_test
  end

  defp true_every_n_first_true_test(reducer) do
    assert ET.reduce(1..4, reducer) ==
           [{1, true}, {2, false}, {3, true}, {4, false}]
  end

  test "ET.Logic.with_index()" do
    ET.Logic.with_index
    |> ET.Reducers.list
    |> logic_test
  end

  test "ET.Logic.with_index(transducer)" do
    identity_trans
    |> ET.Logic.with_index
    |> ET.Reducers.list
    |> logic_test
  end

  defp logic_test(reducer) do
    assert ET.reduce(1..3, reducer) == [{1,0},{2,1},{3,2}]
  end

end
