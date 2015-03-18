defmodule ETLogicTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Wrapped.allow(n)" do
    ET.Wrapped.allow(2)
    |> ET.Reducers.list
    |> allow_n_test
  end

  test "ET.Wrapped.allow(transducer, n)" do
    identity_trans
    |> ET.Wrapped.allow(2)
    |> ET.Reducers.list
    |> allow_n_test
  end

  defp allow_n_test(allow_two) do
    assert ET.reduce([one: true, two: false, three: nil,
                      four: 1, five: true], allow_two) ==
      [{{:one, true}, true}, {{:two, false}, false}, {{:three, nil}, nil},
       {{:four, 1}, 1}, {{:five, true}, false}]
  end

  test "ET.Wrapped.change?()" do
    ET.Wrapped.change?
    |> ET.Reducers.list
    |> change_test
  end

  test "ET.Wrapped.change?(transducer)" do
    identity_trans
    |> ET.Wrapped.change?
    |> ET.Reducers.list
    |> change_test
  end

  defp change_test(r_fun) do
    assert ET.reduce([1,1,1,2,3], r_fun) ==
           [{1, false}, {1, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Wrapped.change?(first: true)" do
    ET.Wrapped.change?(first: true)
    |> ET.Reducers.list
    |> change_first_true_test
  end

  test "ET.Wrapped.change?(transducer, first: true)" do
    identity_trans
    |> ET.Wrapped.change?(first: true)
    |> ET.Reducers.list
    |> change_first_true_test
  end

  defp change_first_true_test(r_fun) do
    assert ET.reduce([1,1,1,2,3], r_fun) ==
           [{1, true}, {1, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Wrapped.change?(change_check)" do
    ET.Wrapped.change?(&(rem(&1, 2)))
    |> ET.Reducers.list
    |> change_change_check_test
  end

  test "ET.Wrapped.change?(transducer, change_check)" do
    identity_trans
    |> ET.Wrapped.change?(&(rem(&1, 2)))
    |> ET.Reducers.list
    |> change_change_check_test
  end

  defp change_change_check_test(r_fun) do
    assert ET.reduce([1,3,1,2,3], r_fun) ==
           [{1, false}, {3, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Wrapped.change?(change_check, first: true)" do
    ET.Wrapped.change?(&(rem(&1, 2)), first: true)
    |> ET.Reducers.list
    |> change_change_check_first_true_test
  end

  test "ET.Wrapped.change?(transducer, change_check, first: true)" do
    identity_trans
    |> ET.Wrapped.change?(&(rem(&1, 2)), first: true)
    |> ET.Reducers.list
    |> change_change_check_first_true_test
  end

  defp change_change_check_first_true_test(r_fun) do
    assert ET.reduce([1,3,1,2,3], r_fun) ==
           [{1, true}, {3, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Wrapped.chunk(inner_r_fun)" do
    ET.Wrapped.chunk(ET.Transducers.take(2) |> ET.Reducers.list)
    |> ET.Reducers.list
    |> chunk_inner_reducer_test
  end

  test "ET.Wrapped.chunk(transducer, inner_r_fun)" do
    identity_trans
    |> ET.Wrapped.chunk(ET.Transducers.take(2) |> ET.Reducers.list)
    |> ET.Reducers.list
    |> chunk_inner_reducer_test
  end

  defp chunk_inner_reducer_test(r_fun) do
    ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], r_fun)
    [[{2, true}, {3, false}]]
  end

  test "ET.Wrapped.chunk(inner_reducer, padding)" do
    ET.Wrapped.chunk((ET.Transducers.take(2) |> ET.Reducers.list), [])
    |> ET.Reducers.list
    |> chunk_inner_reducer_padding_test
  end

  test "ET.Wrapped.chunk(transducer, inner_reducer, padding)" do
    identity_trans
    |> ET.Wrapped.chunk((ET.Transducers.take(2) |> ET.Reducers.list), [])
    |> ET.Reducers.list
    |> chunk_inner_reducer_padding_test
  end

  defp chunk_inner_reducer_padding_test(r_fun) do
    assert ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], r_fun) ==
    [[{2, true}, {3, false}], [{4, true}]]
  end

  test "ET.Wrapped.chunk(inner_reducer, padding) with extra padding" do
    r_fun =
      ET.Wrapped.chunk((ET.Transducers.take(2) |> ET.Reducers.list), 5..8)
      |> ET.Reducers.list

    assert ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], r_fun) ==
    [[{2, true}, {3, false}], [{4, true}, {5, nil}]]
  end

  test "ET.Wrapped.filter()" do
    ET.Wrapped.filter
    |> ET.Reducers.list
    |> filter_test
  end

  test "ET.Wrapped.filter(transducer)" do
    identity_trans
    |> ET.Wrapped.filter
    |> ET.Reducers.list
    |> filter_test
  end

  defp filter_test(r_fun) do
    assert ET.reduce([{1, true}, {2, true}, {3, false}, {4, true}], r_fun) ==
           [{3, false}]
  end

  test "ET.Wrapped.group_by(reducer, reducers)" do
    ET.Wrapped.group_by(ET.Reducers.count,
                      %{2 => ET.Wrapped.unwrap |> ET.Reducers.list})
    |> ET.Reducers.map
    |> group_by_reducer_reducers_test
  end

  test "ET.Wrapped.group_by(transducer, reducer, reducers)" do
    identity_trans
    |> ET.Wrapped.group_by(ET.Reducers.count,
                         %{2 => ET.Wrapped.unwrap |> ET.Reducers.list})
    |> ET.Reducers.map
    |> group_by_reducer_reducers_test
  end

  defp group_by_reducer_reducers_test(count_except_two) do
    assert ET.reduce([{false, 1}, {false, 3}, {:foo, 2}, {false, 1}, {:bar, 2}],
                     count_except_two) ==
           %{1 => 2, 2 => [:foo, :bar], 3 => 1}
  end

  test "ET.Wrapped.group_by(r_fun)" do
    ET.Wrapped.group_by(ET.Wrapped.unwrap |> ET.Reducers.list)
    |> ET.Reducers.map
    |> group_by_reducer_test
  end

  test "ET.Wrapped.group_by(transducer, r_fun)" do
    identity_trans
    |> ET.Wrapped.group_by(ET.Wrapped.unwrap |> ET.Reducers.list)
    |> ET.Reducers.map
    |> group_by_reducer_test
  end

  defp group_by_reducer_test(r_fun) do
    assert ET.reduce([{1,1}, {2,2}, {3,1}, {4,2}], r_fun) ==
    %{1 => [1,3], 2 => [2,4]}
  end

  test "ET.Wrapped.group_by doesn't send items to done reducer" do
    r_fun =
      ET.Wrapped.wrap(&(&1))
      |> ET.Wrapped.group_by(ET.Transducers.take(1)
                           |> ET.Wrapped.unwrap
                           |> ET.Reducers.list)
      |> ET.Transducers.take(1)
      |> ET.Wrapped.unwrap
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) == [1]
  end

  test "ET.Wrapped.halt_after()" do
    ET.Wrapped.halt_after
    |> ET.Reducers.list
    |> halt_after_test
  end

  test "ET.Wrapped.halt_after(transducer)" do
    identity_trans
    |> ET.Wrapped.halt_after
    |> ET.Reducers.list
    |> halt_after_test
  end

  defp halt_after_test(r_fun) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], r_fun) ==
    [{1, false}, {2, false}, {3, true}]
  end

  test "ET.Wrapped.halt_on()" do
    ET.Wrapped.halt_on
    |> ET.Reducers.list
    |> halt_on_test
  end

  test "ET.Wrapped.halt_on(transducer)" do
    identity_trans
    |> ET.Wrapped.halt_on
    |> ET.Reducers.list
    |> halt_on_test
  end

  defp halt_on_test(r_fun) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], r_fun) ==
    [{1, false}, {2, false}]
  end

  test "ET.Wrapped.ignore(n)" do
    ET.Wrapped.ignore(2)
    |> ET.Reducers.list
    |> ignore_n_test
  end

  test "ET.Wrapped.ignore(transducer, n)" do
    identity_trans
    |> ET.Wrapped.ignore(2)
    |> ET.Reducers.list
    |> ignore_n_test
  end

  def ignore_n_test(ignore_two) do
    assert ET.reduce([a: true, b: false, c: true, d: true] ,ignore_two) ==
      [{{:a, true}, false}, {{:b, false}, false},
       {{:c, true}, false}, {{:d, true}, true}]
  end

  test "ET.Wrapped.insert_before(term)" do
    ET.Wrapped.insert_before({:foo, :bar})
    |> ET.Reducers.list
    |> insert_before_term_test
  end

  test "ET.Wrapped.insert_before(transducer, term)" do
    identity_trans
    |> ET.Wrapped.insert_before({:foo, :bar})
    |> ET.Reducers.list
    |> insert_before_term_test
  end

  defp insert_before_term_test(foo_bar_inserter) do
    assert ET.reduce([{1,true}, {2,false}, {3,true}], foo_bar_inserter) ==
           [{:foo, :bar}, {1,true}, {2,false}, {:foo, :bar}, {3,true}]
  end

  test "ET.Wrapped.in_collection(transducible)" do
    ET.Wrapped.in_collection([2, 1, 5])
    |> ET.Reducers.list
    |> logic_in_collection_transducible_test
  end

  test "ET.Wrapped.in_collection(transducer, transducible)" do
    identity_trans
    |> ET.Wrapped.in_collection([2, 1, 5])
    |> ET.Reducers.list
    |> logic_in_collection_transducible_test
  end

  defp logic_in_collection_transducible_test(r_fun) do
    assert ET.reduce([{false, 1}, {true, 3}, {false, 4}, {true, 1}], r_fun) ==
                     [{{false, 1},true}, {{true,3},false},
                      {{false,4},false}, {{true, 1},true}]
  end

  test "ET.Wrapped.in_collection(transducible, one_for_one: true)" do
    ET.Wrapped.in_collection([2, 1, 5], one_for_one: true)
    |> ET.Reducers.list
    |> logic_in_collection_transducible_one_for_one_test
  end

  test "ET.Wrapped.in_collection(transducer, transducible, one_for_one: true)" do
    identity_trans
    |> ET.Wrapped.in_collection([2, 1, 5], one_for_one: true)
    |> ET.Reducers.list
    |> logic_in_collection_transducible_one_for_one_test
  end

  defp logic_in_collection_transducible_one_for_one_test(r_fun) do
    assert ET.reduce([{false, 1}, {true, 3}, {false, 4}, {true, 1}], r_fun) ==
                     [{{false, 1},true}, {{true,3},false},
                      {{false,4},false}, {{true, 1},false}]
  end

  test "ET.Wrapped.in_collection(transducible, one_for_one: true) when transducible is empty" do
    r_fun =
      ET.Wrapped.in_collection([1], one_for_one: true)
      |> ET.Reducers.list

    assert ET.reduce([{false, 1}, {true, 1}], r_fun) ==
           [{{false, 1}, true}, {{true, 1}, nil}]
  end

  test "ET.Wrapped.last_by()" do
    ET.Wrapped.last_by
    |> ET.Reducers.last
    |> last_by_test
  end

  test "ET.Wrapped.last_by(transducer)" do
    identity_trans
    |> ET.Wrapped.last_by
    |> ET.Reducers.last
    |> last_by_test
  end

  defp last_by_test(r_fun) do
    assert ET.reduce([two: false, three: true, one: true, four: false], r_fun) ==
           {:one, true}
  end

  test "ET.Wrapped.last_by() nothing true" do
    r_fun =
      ET.Wrapped.last_by
      |> ET.Reducers.last

    assert ET.reduce([one: false, two: false], r_fun) == nil
  end

  test "ET.Wrapped.negate()" do
    ET.Wrapped.negate
    |> ET.Reducers.list
    |> negate_test
  end

  test "ET.Wrapped.negate(transducer)" do
    identity_trans
    |> ET.Wrapped.negate
    |> ET.Reducers.list
    |> negate_test
  end

  defp negate_test(r_fun) do
    assert ET.reduce([{1, true}, {2, 2}, {3, false}, {4, nil}], r_fun) ==
           [{{1,true},false}, {{2,2},false}, {{3,false},true}, {{4,nil},true}]
  end

  test "ET.Wrapped.reverse_unwrap()" do
    ET.Wrapped.reverse_unwrap
    |> ET.Reducers.list
    |> reverse_unwrap_test
  end

  test "ET.Wrapped.reverse_unwrap(transducer)" do
    identity_trans
    |> ET.Wrapped.reverse_unwrap
    |> ET.Reducers.list
    |> reverse_unwrap_test
  end

  defp reverse_unwrap_test(r_fun) do
    assert ET.reduce([{1, true}, {2, 2}, {3, false}, {4, nil}], r_fun) ==
           [true, 2, false, nil]
  end

  test "ET.Wrapped.sort_by()" do
    ET.Wrapped.sort_by
    |> ET.Reducers.list
    |> sort_by_test
  end

  test "ET.Wrapped.sort_by(transducer)" do
    identity_trans
    |> ET.Wrapped.sort_by
    |> ET.Reducers.list
    |> sort_by_test
  end

  defp sort_by_test(sort_r_fun) do
    assert ET.reduce([three: 3, one: 1, four: 4, two: 2], sort_r_fun) ==
           [one: 1, two: 2, three: 3, four: 4]
  end

  test "ET.Wrapped.sort_by(fun)" do
    ET.Wrapped.sort_by(&>=/2)
    |> ET.Reducers.list
    |> sort_by_fun_test
  end

  test "ET.Wrapped.sort_by(transducer, fun)" do
    identity_trans
    |> ET.Wrapped.sort_by(&>=/2)
    |> ET.Reducers.list
    |> sort_by_fun_test
  end

  defp sort_by_fun_test(rev_sort_r_fun) do
    assert ET.reduce([three: 3, one: 1, four: 4, two: 2], rev_sort_r_fun) ==
           [four: 4, three: 3, two: 2, one: 1]
  end

  test "ET.Wrapped.true_every(n)" do
    ET.Wrapped.true_every(2)
    |> ET.Reducers.list
    |> true_every_n_test
  end

  test "ET.Wrapped.true_every(n, transducer)" do
    identity_trans
    |> ET.Wrapped.true_every(2)
    |> ET.Reducers.list
    |> true_every_n_test
  end

  defp true_every_n_test(r_fun) do
    assert ET.reduce(1..4, r_fun) ==
           [{1, false}, {2, true}, {3, false}, {4, true}]
  end

  test "ET.Wrapped.true_every(n, first: true)" do
    ET.Wrapped.true_every(2, first: true)
    |> ET.Reducers.list
    |> true_every_n_first_true_test
  end

  test "ET.Wrapped.true_every(transducer, n, first: true)" do
    identity_trans
    |> ET.Wrapped.true_every(2, first: true)
    |> ET.Reducers.list
    |> true_every_n_first_true_test
  end

  defp true_every_n_first_true_test(r_fun) do
    assert ET.reduce(1..4, r_fun) ==
           [{1, true}, {2, false}, {3, true}, {4, false}]
  end

  test "ET.Wrapped.unfold(acc, fun)" do
    ET.Wrapped.unfold(0, fn e, a -> r = e+a; {rem(r,3), r} end)
    |> ET.Reducers.list
    |> unfold_acc_fun_test
  end

  test "ET.Wrapped.unfold(transducer, acc, fun)" do
    identity_trans
    |> ET.Wrapped.unfold(0, fn e, a -> r = e+a; {rem(r,3), r} end)
    |> ET.Reducers.list
    |> unfold_acc_fun_test
  end

  defp unfold_acc_fun_test(sum_r_fun) do
    assert ET.reduce(1..5, sum_r_fun) ==
           [{1,1},{2,0},{3,0},{4,1},{5,0}]
  end

  test "ET.Wrapped.unique_by()" do
    ET.Wrapped.unique_by
    |> ET.Reducers.list
    |> unique_by_test
  end

  test "ET.Wrapped.unique_by(transducer)" do
    identity_trans
    |> ET.Wrapped.unique_by
    |> ET.Reducers.list
    |> unique_by_test
  end

  defp unique_by_test(unique_by) do
    assert ET.reduce([one: 1, two: 2, three: 1, four: 4], unique_by) ==
           [one: 1, two: 2, four: 4]
  end

  test "ET.Wrapped.unwrap()" do
    ET.Wrapped.unwrap
    |> ET.Reducers.list
    |> unwrap_test
  end

  test "ET.Wrapped.unwrap(transducer)" do
    identity_trans
    |> ET.Wrapped.unwrap
    |> ET.Reducers.list
    |> unwrap_test
  end

  defp unwrap_test(r_fun) do
    assert ET.reduce([{1, true}, {2, false}, {3, true}], r_fun) ==
           [1,2,3]
  end

  test "ET.Wrapped.unwrap(n)" do
    ET.Wrapped.unwrap(2)
    |> ET.Reducers.list
    |> unwrap_n_test
  end

  test "ET.Wrapped.unwrap(transducer, n)" do
    identity_trans
    |> ET.Wrapped.unwrap(2)
    |> ET.Reducers.list
    |> unwrap_n_test
  end

  defp unwrap_n_test(r_fun) do
    assert ET.reduce([{{1, true}, false}, {{2, false}, false}, {{3, true}, true}], r_fun) ==
           [1,2,3]
  end

  test "ET.Wrapped.with_index()" do
    ET.Wrapped.with_index
    |> ET.Reducers.list
    |> with_index_test
  end

  test "ET.Wrapped.with_index(transducer)" do
    identity_trans
    |> ET.Wrapped.with_index
    |> ET.Reducers.list
    |> with_index_test
  end

  defp with_index_test(r_fun) do
    assert ET.reduce(1..3, r_fun) == [{1,0},{2,1},{3,2}]
  end

  test "ET.Wrapped.wrap(fun)" do
    ET.Wrapped.wrap(&(rem(&1,3)))
    |> ET.Reducers.list
    |> wrap_test
  end

  test "ET.Wrapped.wrap(transducer, fun)" do
    identity_trans
    |> ET.Wrapped.wrap(&(rem(&1,3)))
    |> ET.Reducers.list
    |> wrap_test
  end

  defp wrap_test(r_fun) do
    assert ET.reduce(1..4, r_fun) ==
           [{1,1},{2,2},{3,0},{4,1}]
  end

  test "ET.Wrapped.zip()" do
    ET.Wrapped.zip
    |> ET.Reducers.list
    |> zip_test
  end

  test "ET.Wrapped.zip(transducer)" do
    identity_trans
    |> ET.Wrapped.zip
    |> ET.Reducers.list
    |> zip_test
  end

  defp zip_test(zip_r_fun) do
    assert ET.reduce([1..2, 3..5, [6]], zip_r_fun) ==
    [{1,true}, {3,false}, {6,false}, {2,true}, {4,false}, {5,true}]
  end

end
