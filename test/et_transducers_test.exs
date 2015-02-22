defmodule ETTransducersTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Transducers.at_index(n)" do
    ET.Transducers.at_index(2)
    |> ET.Reducers.list
    |> at_index_n_test
  end

  test "ET.Transducers.at_index(transducer, n)" do
    identity_trans
    |> ET.Transducers.at_index(2)
    |> ET.Reducers.list
    |> at_index_n_test
  end

  defp at_index_n_test(reducer) do
    assert ET.reduce(1..4, reducer) == [3]
  end

  test "ET.Transducers.at_indices(transducible)" do
    ET.Transducers.at_indices([1,3])
    |> ET.Reducers.list
    |> at_indices_transducible_test
  end

  test "ET.Transducers.at_indices(transducer, transducible)" do
    identity_trans
    |> ET.Transducers.at_indices([1,3])
    |> ET.Reducers.list
    |> at_indices_transducible_test
  end

  defp at_indices_transducible_test(reducer) do
    assert ET.reduce(2..6, reducer) == [3,5]
  end

  test "ET.Transducers.at_indices(transducible) early termination" do
    r_fun =
      ET.Transducers.at_indices([1])
      |> ET.Reducers.count
    reducer = {r_fun, r_fun.(nil, :init)}

    assert {cont, {_,{:cont,_}} = reducer} = ET.Transducer.reduce_one(1..3, reducer)
    assert {_cont, {_,{:halt,_}} = reducer} = ET.Transducer.reduce_one(cont, reducer)
    assert 1 == ET.Transducer.finish(reducer)
  end

  test "ET.Transducers.at_indices(transducible) early termination taking first element" do
    reducer =
      ET.Transducers.at_indices([0,2])
      |> ET.Reducers.count

    assert ET.reduce(1..3, reducer) == 2
  end

  test "ET.Transducers.chunk(size)" do
    ET.Transducers.chunk(2)
    |> ET.Reducers.list
    |> chunk_size_test
  end

  test "ET.Transducers.chunk(transducer, size)" do
    identity_trans
    |> ET.Transducers.chunk(2)
    |> ET.Reducers.list
    |> chunk_size_test
  end

  defp chunk_size_test(reducer) do
    assert ET.reduce(1..5, reducer) == [[1,2], [3,4]]
  end

  test "ET.Transducers.chunk(size, step)" do
    ET.Transducers.chunk(2,1)
    |> ET.Reducers.list
    |> chunk_size_step_test
  end

  test "ET.Transducers.chunk(transducer, size, step)" do
    identity_trans
    |> ET.Transducers.chunk(2,1)
    |> ET.Reducers.list
    |> chunk_size_step_test
  end

  defp chunk_size_step_test(reducer) do
    assert ET.reduce(1..4, reducer) == [[1,2], [2,3], [3,4]]
  end

  test "ET.Transducers.chunk(size, inner_reducer)" do
    ET.Transducers.chunk(2, ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_size_inner_reducer_test
  end

  test "ET.Transducers.chunk(transducersize, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk(2, ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_size_inner_reducer_test
  end

  defp chunk_size_inner_reducer_test(reducer) do
    assert ET.reduce(1..5, reducer) == [2, 2]
  end

  test "ET.Transducers.chunk(size, padding)" do
    ET.Transducers.chunk(2, [:a, :b, :c])
    |> ET.Reducers.list
    |> chunk_size_padding_test
  end

  test "ET.Transducers.chunk(transducer, size, padding)" do
    identity_trans
    |> ET.Transducers.chunk(2, [:a, :b, :c])
    |> ET.Reducers.list
    |> chunk_size_padding_test
  end

  defp chunk_size_padding_test(reducer) do
    assert ET.reduce(1..5, reducer) == [[1,2], [3,4], [5,:a]]
  end

  test "ET.Transducers.chunk(size, empty_padding)" do
    chunker = ET.Transducers.chunk(2, []) |> ET.Reducers.list
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4], [5]]
  end

  test "ET.Transducers.chunk(size, step, padding)" do
    ET.Transducers.chunk(2, 1, [:a])
    |> ET.Reducers.list
    |> chunk_size_step_padding_test
  end

  test "ET.Transducers.chunk(transducer, size, step, padding)" do
    identity_trans
    |> ET.Transducers.chunk(2, 1, [:a])
    |> ET.Reducers.list
    |> chunk_size_step_padding_test
  end

  defp chunk_size_step_padding_test(reducer) do
    assert ET.reduce(1..3, reducer) == [[1,2], [2,3], [3,:a]]
  end

  test "ET.Transducers.chunk(size, step, inner_reducer)" do
    ET.Transducers.chunk(2, 1, ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_size_step_inner_reducer_test
  end

  test "ET.Transducers.chunk(transducer, size, step, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk(2, 1, ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_size_step_inner_reducer_test
  end

  defp chunk_size_step_inner_reducer_test(reducer) do
    assert ET.reduce(1..4, reducer) == [2, 2, 2]
  end

  test "ET.Transducers.chunk(size, step, padding, inner_reducer)" do
    ET.Transducers.chunk(2, 1, [:a], ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_size_step_padding_inner_reducer_test
  end

  test "ET.Transducers.chunk(transducer, size, step, padding, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk(2, 1, [:a], ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_size_step_padding_inner_reducer_test
  end

  defp chunk_size_step_padding_inner_reducer_test(reducer) do
    assert ET.reduce(1..3, reducer) == [2, 2, 2]
  end
  #TODO test early :halt timing and order for inner reducer
  #TODO test generic chunk

  test "ET.Transducers.chunk_by()" do
    ET.Transducers.chunk_by()
    |> ET.Reducers.list
    |> chunk_by_test
  end

  test "ET.Transducers.chunk_by(transducer)" do
    identity_trans
    |> ET.Transducers.chunk_by()
    |> ET.Reducers.list
    |> chunk_by_test
  end

  defp chunk_by_test(reducer) do
    assert ET.reduce([1,2,2,3,2], reducer) == [[1],[2,2],[3],[2]]
  end

  test "ET.Transducers.chunk_by(map_fun)" do
    ET.Transducers.chunk_by(&(rem(&1,3)==0))
    |> ET.Reducers.list
    |> chunk_by_map_fun_test
  end

  test "ET.Transducers.chunk_by(transducer, map_fun)" do
    identity_trans
    |> ET.Transducers.chunk_by(&(rem(&1,3)==0))
    |> ET.Reducers.list
    |> chunk_by_map_fun_test
  end

  defp chunk_by_map_fun_test(reducer) do
    assert ET.reduce(1..4, reducer) == [[1,2],[3],[4]]
  end

  test "ET.Transducers.chunk_by(map_fun, inner_reducer)" do
    ET.Transducers.chunk_by(&(rem(&1,3)==0), ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_by_map_fun_inner_reducer_test
  end

  test "ET.Transducers.chunk_by(transducer, map_fun, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk_by(&(rem(&1,3)==0), ET.Reducers.count())
    |> ET.Reducers.list
    |> chunk_by_map_fun_inner_reducer_test
  end

  defp chunk_by_map_fun_inner_reducer_test(reducer) do
    assert ET.reduce(1..4, reducer) == [2,1,1]
  end


  test "ET.Transducers.concat()" do
    ET.Transducers.concat
    |> ET.Reducers.list
    |> concat_test
  end

  test "ET.Transducers.concat(transducer)" do
    identity_trans
    |> ET.Transducers.concat
    |> ET.Reducers.list
    |> concat_test
  end

  defp concat_test(reducer) do
    assert ET.reduce([1..2, 3..5, 6..7], reducer) == [1,2,3,4,5,6,7]
  end

  test "ET.Transducers.drop(n)" do
    ET.Transducers.drop(3)
    |> ET.Reducers.list
    |> drop_n_test
  end

  test "ET.Transducers.drop(transducer,n)" do
    identity_trans
    |> ET.Transducers.drop(3)
    |> ET.Reducers.list
    |> drop_n_test
  end

  defp drop_n_test(reducer) do
    assert ET.reduce(1..5, reducer) == [4,5]
  end

  test "ET.Transducers.drop(-n)" do
    reducer =
      ET.Transducers.drop(-3)
      |> ET.Reducers.list

    assert ET.reduce(1..5, reducer) == [1,2]
  end

  test "ET.Transducers.drop_while(fun)" do
    ET.Transducers.drop_while(&(rem(&1, 3) != 0))
    |> ET.Reducers.list
    |> drop_while_fun_test
  end

  test "ET.Transducers.drop_while(transducer, fun)" do
    identity_trans
    |> ET.Transducers.drop_while(&(&1<3))
    |> ET.Reducers.list
    |> drop_while_fun_test
  end

  defp drop_while_fun_test(reducer) do
    assert ET.reduce(1..4, reducer) == [3,4]
  end

  test "ET.Transducers.ensure(n)" do
    ET.Transducers.ensure(2)
    |> ET.Transducers.take(1)
    |> ET.Reducers.list
    |> ensure_test
  end

  test "ET.Transducers.ensure(transducer, n)" do
    identity_trans
    |> ET.Transducers.ensure(2)
    |> ET.Transducers.take(1)
    |> ET.Reducers.list
    |> ensure_test
  end

  defp ensure_test(r_fun) do
    coll = [1,2,3]
    reducer = {r_fun, r_fun.(nil, :init)}
    assert {coll, {_,{:cont,_}} = reducer} = ET.Transducer.reduce_one(coll, reducer)
    assert {_coll, {_,{:halt,_}} = reducer} = ET.Transducer.reduce_one(coll, reducer)
    assert [1] = ET.Transducer.finish(reducer)
  end

  test "ET.Transducers.filter(function)" do
    ET.Transducers.filter(&(rem(&1,3)==0))
    |> ET.Reducers.list
    |> filter_function_test
  end

  test "ET.Transducers.filter(transducer, function)" do
    identity_trans
    |> ET.Transducers.filter(&(rem(&1,3)==0))
    |> ET.Reducers.list
    |> filter_function_test
  end

  defp filter_function_test(reducer) do
    assert ET.reduce(1..7, reducer) == [3,6]
  end

  test "ET.Transducers.find_indices(fun)" do
    ET.Transducers.find_indices(&(rem(&1,3)==0))
    |> ET.Reducers.list
    |> find_indices_fun_test
  end

  test "ET.Transducers.find_indices(transducer, fun)" do
    identity_trans
    |> ET.Transducers.find_indices(&(rem(&1,3)==0))
    |> ET.Reducers.list
    |> find_indices_fun_test
  end

  defp find_indices_fun_test(div_by_three) do
    assert ET.reduce(2..7, div_by_three) ==
           [1, 4]
  end

  test "ET.Transducers.group_by(fun)" do
    ET.Transducers.group_by(&(rem(&1,3)))
    |> ET.Reducers.map
    |> group_by_fun_test
  end

  test "ET.Transducers.group_by(transducer, fun)" do
    identity_trans
    |> ET.Transducers.group_by(&(rem(&1,3)))
    |> ET.Reducers.map
    |> group_by_fun_test
  end

  defp group_by_fun_test(rem_three) do
    assert ET.reduce(1..4, rem_three) ==
           %{0 => [3], 1 => [1,4], 2 => [2]}
  end

  test "ET.Transducers.group_by(fun, reducer)" do
    ET.Transducers.group_by(&(rem(&1,3)), ET.Reducers.count)
    |> ET.Reducers.map
    |> group_by_fun_reducer_test
  end

  test "ET.Transducers.group_by(transducer, fun, reducer)" do
    identity_trans
    |> ET.Transducers.group_by(&(rem(&1,3)), ET.Reducers.count)
    |> ET.Reducers.map
    |> group_by_fun_reducer_test
  end

  defp group_by_fun_reducer_test(rem_three_count) do
    assert ET.reduce(1..4, rem_three_count) == %{0 => 1, 1 => 2, 2 => 1}
  end

  test "ET.Transducers.group_by(fun, reducer, reducers)" do
    ET.Transducers.group_by(&(rem(&1,3)), ET.Reducers.count, %{0 => ET.Reducers.list})
    |> ET.Reducers.map
    |> group_by_fun_reducer_reducers_test
  end

  test "ET.Transducers.group_by(transducer, fun, reducer, reducers)" do
    identity_trans
    |> ET.Transducers.group_by(&(rem(&1,3)), ET.Reducers.count, %{0 => ET.Reducers.list})
    |> ET.Reducers.map
    |> group_by_fun_reducer_reducers_test
  end

  defp group_by_fun_reducer_reducers_test(count_except_div_three) do
    assert ET.reduce(1..7, count_except_div_three) ==
           %{0 => [3,6], 1 => 3, 2 => 2}
  end

  test "ET.Transducers.intersperse(term)" do
    ET.Transducers.intersperse(:foo)
    |> ET.Reducers.list
    |> intersperse_term_test
  end

  test "ET.Transducers.intersperse(transducer, term)" do
    identity_trans
    |> ET.Transducers.intersperse(:foo)
    |> ET.Reducers.list
    |> intersperse_term_test
  end

  defp intersperse_term_test(foo_inserter) do
    assert ET.reduce(1..3, foo_inserter) ==
           [1, :foo, 2, :foo, 3]
  end


  test "ET.Transducers.map(map_fun)" do
    ET.Transducers.map(&(&1+1))
    |> ET.Reducers.list
    |> map_map_fun_test
  end

  test "ET.Transducers.map(transducer, map_fun)" do
    identity_trans
    |> ET.Transducers.map(&(&1+1))
    |> ET.Reducers.list
    |> map_map_fun_test
  end

  defp map_map_fun_test(reducer) do
    assert ET.reduce(1..3, reducer) == [2,3,4]
  end

  test "ET.Transducers.reverse()" do
    ET.Transducers.reverse
    |> ET.Reducers.list
    |> reverse_test
  end

  test "ET.Transducers.reverse(transducer)" do
    identity_trans
    |> ET.Transducers.reverse
    |> ET.Reducers.list
    |> reverse_test
  end

  defp reverse_test(reverse_r_fun) do
    assert ET.reduce(1..4, reverse_r_fun) ==
           [4,3,2,1]
  end

  test "ET.Transducers.scan(acc, fun)" do
    ET.Transducers.scan(1, &Kernel.*/2)
    |> ET.Reducers.list
    |> scan_acc_fun_test
  end

  test "ET.Transducers.scan(transducer, acc, fun)" do
    identity_trans
    |> ET.Transducers.scan(1, &Kernel.*/2)
    |> ET.Reducers.list
    |> scan_acc_fun_test
  end

  defp scan_acc_fun_test(mult_scan_r_fun) do
    assert ET.reduce(1..4, mult_scan_r_fun) ==
           [1,2,6,24]
  end

  test "ET.Transducers.shuffle()" do
    ET.Transducers.shuffle
    |> ET.Reducers.list
    |> shuffle_test
  end

  test "ET.Transducers.shuffle(transducer)" do
    identity_trans
    |> ET.Transducers.shuffle
    |> ET.Reducers.list
    |> shuffle_test
  end

  defp shuffle_test(shuffle_r_fun) do
    :random.seed({5220, 72574, 520325})
    assert ET.reduce(1..4, shuffle_r_fun) ==
           [3,1,4,2]
  end

  test "ET.Tranducers.slice(positive_start, count)" do
    ET.Transducers.slice(2, 3)
    |> ET.Reducers.list
    |> slice_positive_start_count_test
  end

  test "ET.Tranducers.slice(transducer, positive_start, count)" do
    identity_trans
    |> ET.Transducers.slice(2, 3)
    |> ET.Reducers.list
    |> slice_positive_start_count_test
  end

  defp slice_positive_start_count_test(two_three_r_fun) do
    assert ET.reduce(1..6, two_three_r_fun) ==
           [3,4,5]
  end

  test "ET.Tranducers.slice(negative_start, count)" do
    r_fun =
      ET.Transducers.slice(-4, 3)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           [3,4,5]
  end

  test "ET.Transducers.slice(positive..positive)" do
    ET.Transducers.slice(2..4)
    |> ET.Reducers.list
    |> slice_positive_positive_test
  end

  test "ET.Transducers.slice(transducer, positive..positive)" do
    identity_trans
    |> ET.Transducers.slice(2..4)
    |> ET.Reducers.list
    |> slice_positive_positive_test
  end

  defp slice_positive_positive_test(two_to_four_r_fun) do
    assert ET.reduce(1..6, two_to_four_r_fun) ==
           [3,4,5]
  end

  test "ET.Transducers.slice(positive..positive) inverted" do
    r_fun =
      ET.Transducers.slice(4..2)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) == []
  end

  test "ET.Transducers.slice(negative..negative)" do
    r_fun =
      ET.Transducers.slice(-4..-2)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           [3,4,5]
  end

  test "ET.Transducers.slice(negative..negative) inverted" do
    r_fun =
      ET.Transducers.slice(-2..-4)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           []
  end

  test "ET.Transducers.slice(positive..negative)" do
    r_fun =
      ET.Transducers.slice(2..-2)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           [3,4,5]
  end

  test "ET.Transducers.slice(positive..negative) inverted" do
    r_fun =
      ET.Transducers.slice(4..-4)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           []
  end

  test "ET.Transducers.slice(negative..positive)" do
    r_fun =
      ET.Transducers.slice(-4..4)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           [3,4,5]
  end

  test "ET.Transducers.slice(negative..positive) inverted" do
    r_fun =
      ET.Transducers.slice(-2..2)
      |> ET.Reducers.list

    assert ET.reduce(1..6, r_fun) ==
           []
  end

  test "ET.Transducers.sort()" do
    ET.Transducers.sort
    |> ET.Reducers.list
    |> sort_test
  end

  test "ET.Transducers.sort(transducer)" do
    identity_trans
    |> ET.Transducers.sort
    |> ET.Reducers.list
    |> sort_test
  end

  defp sort_test(sort_r_fun) do
    assert ET.reduce([3,1,4,2], sort_r_fun) ==
           [1,2,3,4]
  end

  test "ET.Transducers.sort_by(fun)" do
    ET.Transducers.sort_by(&(-&1))
    |> ET.Reducers.list
    |> sort_by_fun_test
  end

  test "ET.Transducers.sort_by(transducer, fun)" do
    identity_trans
    |> ET.Transducers.sort_by(&(-&1))
    |> ET.Reducers.list
    |> sort_by_fun_test
  end

  defp sort_by_fun_test(neg_sort_r_fun) do
    assert ET.reduce([3,1,4,2], neg_sort_r_fun) ==
           [4,3,2,1]
  end

  test "ET.Transducers.sort_by(fun, fun)" do
    ET.Transducers.sort_by(&(&1), &>=/2)
    |> ET.Reducers.list
    |> sort_by_fun_fun_test
  end

  test "ET.Transducers.sort_by(transducer, fun, fun)" do
    identity_trans
    |> ET.Transducers.sort_by(&(&1), &>=/2)
    |> ET.Reducers.list
    |> sort_by_fun_fun_test
  end

  defp sort_by_fun_fun_test(rev_sort_r_fun) do
    assert ET.reduce([3,1,4,2], rev_sort_r_fun) ==
           [4,3,2,1]
  end

  test "ET.Transducers.split(n, r_fun, r_fun)" do
    ET.Transducers.split(2, ET.Reducers.count, ET.Reducers.list)
    |> ET.Reducers.list
    |> split_n_r_fun_r_fun_test
  end

  test "ET.Transducers.split(transducer, n, r_fun, r_fun)" do
    identity_trans
    |> ET.Transducers.split(2, ET.Reducers.count, ET.Reducers.list)
    |> ET.Reducers.list
    |> split_n_r_fun_r_fun_test
  end

  defp split_n_r_fun_r_fun_test(two_count_list) do
    assert ET.reduce(1..5, two_count_list) == [2, [3,4,5]]
  end

  test "ET.Transducers.split(n, r_fun)" do
    ET.Transducers.split(2, ET.Reducers.count)
    |> ET.Reducers.list
    |> split_n_r_fun_test
  end

  test "ET.Transducers.split(transducer, n, r_fun)" do
    identity_trans
    |> ET.Transducers.split(2, ET.Reducers.count)
    |> ET.Reducers.list
    |> split_n_r_fun_test
  end

  defp split_n_r_fun_test(two_count) do
    assert ET.reduce(1..5, two_count) == [2, 3]
  end

  test "ET.Transducers.split(n)" do
    ET.Transducers.split(2)
    |> ET.Reducers.list
    |> split_n_test
  end

  test "ET.Transducers.split(transducer, n)" do
    identity_trans
    |> ET.Transducers.split(2)
    |> ET.Reducers.list
    |> split_n_test
  end

  defp split_n_test(two_count) do
    assert ET.reduce(1..5, two_count) == [[1,2], [3,4,5]]
  end

  test "ET.Transducers.split(n, r_fun) early inner termination" do
    r_fun =
      ET.Transducers.split(2, ET.Transducers.take(1) |> ET.Reducers.list)
      |> ET.Reducers.list

    assert ET.reduce(1..3, r_fun) == [[1], [3]]
    assert ET.reduce(1..5, r_fun) == [[1], [3]]
  end

  test "ET.Transducers.split(n) early outer termination" do
    r_fun =
      ET.Transducers.split(2)
      |> ET.Transducers.take(1)
      |> ET.Reducers.list

    assert ET.reduce(1..5, r_fun) == [[1,2]]
  end

  test "ET.Transducers.split_while(fun, r_fun, r_fun)" do
    ET.Transducers.split_while(&(&1 < 3), ET.Reducers.count, ET.Reducers.list)
    |> ET.Reducers.list
    |> split_while_fun_r_fun_r_fun_test
  end

  test "ET.Transducers.split_while(transducers, fun, r_fun, r_fun)" do
    identity_trans
    |> ET.Transducers.split_while(&(&1 < 3), ET.Reducers.count, ET.Reducers.list)
    |> ET.Reducers.list
    |> split_while_fun_r_fun_r_fun_test
  end

  defp split_while_fun_r_fun_r_fun_test(under_three_count) do
    ET.reduce(1..5, under_three_count) == [2,[3,4,5]]
  end

  test "ET.Transducers.split_while(fun, r_fun)" do
    ET.Transducers.split_while(&(&1 < 3), ET.Reducers.count)
    |> ET.Reducers.list
    |> split_while_fun_r_fun_test
  end

  test "ET.Transducers.split_while(transducers, fun, r_fun)" do
    identity_trans
    |> ET.Transducers.split_while(&(&1 < 3), ET.Reducers.count)
    |> ET.Reducers.list
    |> split_while_fun_r_fun_test
  end

  defp split_while_fun_r_fun_test(under_three_count) do
    ET.reduce(1..5, under_three_count) == [2,3]
  end

  test "ET.Transducers.split_while(fun)" do
    ET.Transducers.split_while(&(&1 < 3))
    |> ET.Reducers.list
    |> split_while_fun_test
  end

  test "ET.Transducers.split_while(transducer, fun)" do
    identity_trans
    |> ET.Transducers.split_while(&(&1 < 3))
    |> ET.Reducers.list
    |> split_while_fun_test
  end

  defp split_while_fun_test(under_three) do
    assert ET.reduce(1..5, under_three) ==
                     [[1,2], [3,4,5]]
  end

  test "ET.Transducers.split_while(fun) with empty first half" do
    r_fun =
      ET.Transducers.split_while(&(&1 < 3))
      |> ET.Reducers.list

    assert ET.reduce(4..6, r_fun) == [[], [4,5,6]]
  end

  test "ET.Transducers.split_while(fun) with empty second half" do
    r_fun =
      ET.Transducers.split_while(&(&1 < 3))
      |> ET.Reducers.list

    assert ET.reduce(1..2, r_fun) == [[1,2], []]
  end

  test "ET.Transducers.split_while(fun) with no input" do
    r_fun =
      ET.Transducers.split_while(&(&1 < 3))
      |> ET.Reducers.list

    assert ET.reduce([], r_fun) == [[], []]
  end

  test "ET.Transducers.split_while(fun, r_fun) r_fun early termination" do
    r_fun =
      ET.Transducers.split_while(&(&1 < 3),
        ET.Transducers.take(1) |> ET.Reducers.list)
        |> ET.Reducers.list

    assert ET.reduce(1..3, r_fun) == [[1], [3]]
    assert ET.reduce(1..4, r_fun) == [[1], [3]]
  end

  test "ET.Transducers.split_while(fun) early main termination" do
    r_fun =
      ET.Transducers.split_while(&(&1 < 3))
      |> ET.Transducers.take(1)
      |> ET.Reducers.list

    assert ET.reduce(1..5, r_fun) == [[1,2]]
  end

  test "ET.Transducers.take(positive_n)" do
    ET.Transducers.take(3)
    |> ET.Reducers.list
    |> take_positive_n_test
  end

  test "ET.Transducers.take(transducer, positive_n)" do
    identity_trans
    |> ET.Transducers.take(3)
    |> ET.Reducers.list
    |> take_positive_n_test
  end

  defp take_positive_n_test(reducer) do
    assert ET.reduce([1], reducer) == [1]
    assert ET.reduce(1..4, reducer) == [1,2,3]
  end

  test "ET.Transducers.take(negative_n)" do
    last_three_r_fun =
      ET.Transducers.take(-3)
      |> ET.Reducers.list

    assert ET.reduce(1..5, last_three_r_fun) == [3,4,5]
    assert ET.reduce(1..2, last_three_r_fun) == [1,2]
  end

  test "ET.Transducers.take_every(n)" do
    ET.Transducers.take_every(3)
    |> ET.Reducers.list
    |> take_every_n_test
  end

  test "ET.Transducers.take_every(transducer, n)" do
    identity_trans
    |> ET.Transducers.take_every(3)
    |> ET.Reducers.list
    |> take_every_n_test
  end

  defp take_every_n_test(take_three_r_fun) do
    assert ET.reduce(1..8, take_three_r_fun) ==
           [1,4,7]
  end


  test "ET.Transducers.take_while(fun)" do
    ET.Transducers.take_while(&(&1<2))
    |> ET.Reducers.list
    |> take_while_fun_test
  end

  test "ET.Transducers.take_while(transducer, fun)" do
    identity_trans
    |> ET.Transducers.take_while(&(&1<2))
    |> ET.Reducers.list
    |> take_while_fun_test
  end

  defp take_while_fun_test(take_lt_two_r_fun) do
    assert ET.reduce([0,1,0,2,0,1], take_lt_two_r_fun) ==
           [0,1,0]
  end

  test "ET.Transducers.zip()" do
    ET.Transducers.zip
    |> ET.Reducers.list
    |> zip_test
  end

  test "ET.Transducers.zip(transducer)" do
    identity_trans
    |> ET.Transducers.zip
    |> ET.Reducers.list
    |> zip_test
  end

  defp zip_test(reducer) do
    assert ET.reduce([1..4, [8, 9]], reducer) ==
      [1, 8, 2, 9, 3, 4]
  end

  test "ET.Transducers.zip properly terminates early" do
    zip_two =
      ET.Transducers.zip
      |> ET.Transducers.take(2)
      |> ET.Reducers.list

    assert ET.reduce([[1,2],[3,4],[5,6]], zip_two) == [1,3]
  end
end
