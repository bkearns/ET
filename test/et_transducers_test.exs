defmodule ETTransducersTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))
  
  test "ET.Transducers.chunk(size)" do
    ET.Transducers.chunk(2)
    |> ET.Reducers.list()
    |> chunk_size_test
  end

  test "ET.Transducers.chunk(transducer, size)" do
    identity_trans
    |> ET.Transducers.chunk(2)
    |> ET.Reducers.list()
    |> chunk_size_test
  end

  defp chunk_size_test(reducer) do
    assert ET.reduce(1..5, reducer) == [[1,2], [3,4]]
  end

  test "ET.Transducers.chunk(size, step)" do
    ET.Transducers.chunk(2,1)
    |> ET.Reducers.list()
    |> chunk_size_step_test
  end
  
  test "ET.Transducers.chunk(transducer, size, step)" do
    identity_trans
    |> ET.Transducers.chunk(2,1)
    |> ET.Reducers.list()
    |> chunk_size_step_test
  end

  defp chunk_size_step_test(reducer) do
    assert ET.reduce(1..4, reducer) == [[1,2], [2,3], [3,4]]
  end

  test "ET.Transducers.chunk(size, inner_reducer)" do
    ET.Transducers.chunk(2, ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_size_inner_reducer_test
  end

  test "ET.Transducers.chunk(transducersize, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk(2, ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_size_inner_reducer_test
  end

  defp chunk_size_inner_reducer_test(reducer) do
    assert ET.reduce(1..5, reducer) == [2, 2]
  end
  
  test "ET.Transducers.chunk(size, padding)" do
    ET.Transducers.chunk(2, [:a, :b, :c])
    |> ET.Reducers.list()
    |> chunk_size_padding_test
  end

  test "ET.Transducers.chunk(transducer, size, padding)" do
    identity_trans
    |> ET.Transducers.chunk(2, [:a, :b, :c])
    |> ET.Reducers.list()
    |> chunk_size_padding_test
  end

  defp chunk_size_padding_test(reducer) do
    assert ET.reduce(1..5, reducer) == [[1,2], [3,4], [5,:a]]
  end
  
  test "ET.Transducers.chunk(size, empty_padding)" do
    chunker = ET.Transducers.chunk(2, []) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4], [5]]
  end

  test "ET.Transducers.chunk(size, step, padding)" do
    ET.Transducers.chunk(2, 1, [:a])
    |> ET.Reducers.list()
    |> chunk_size_step_padding_test
  end

  test "ET.Transducers.chunk(transducer, size, step, padding)" do
    identity_trans
    |> ET.Transducers.chunk(2, 1, [:a])
    |> ET.Reducers.list()
    |> chunk_size_step_padding_test
  end

  defp chunk_size_step_padding_test(reducer) do
    assert ET.reduce(1..3, reducer) == [[1,2], [2,3], [3,:a]]
  end
  
  test "ET.Transducers.chunk(size, step, inner_reducer)" do
    ET.Transducers.chunk(2, 1, ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_size_step_inner_reducer_test
  end

  test "ET.Transducers.chunk(transducer, size, step, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk(2, 1, ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_size_step_inner_reducer_test
  end

  defp chunk_size_step_inner_reducer_test(reducer) do
    assert ET.reduce(1..4, reducer) == [2, 2, 2]
  end
  
  test "ET.Transducers.chunk(size, step, padding, inner_reducer)" do
    ET.Transducers.chunk(2, 1, [:a], ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_size_step_padding_inner_reducer_test
  end

  test "ET.Transducers.chunk(transducer, size, step, padding, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk(2, 1, [:a], ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_size_step_padding_inner_reducer_test
  end

  defp chunk_size_step_padding_inner_reducer_test(reducer) do
    assert ET.reduce(1..3, reducer) == [2, 2, 2]
  end
  #TODO test early :halt timing and order for inner reducer
  #TODO test generic chunk  

  test "ET.Transducers.chunk_by()" do
    ET.Transducers.chunk_by()
    |> ET.Reducers.list()
    |> chunk_by_test
  end

  test "ET.Transducers.chunk_by(transducer)" do
    identity_trans
    |> ET.Transducers.chunk_by()
    |> ET.Reducers.list()
    |> chunk_by_test
  end

  defp chunk_by_test(reducer) do
    assert ET.reduce([1,2,2,3,2], reducer) == [[1],[2,2],[3],[2]]
  end
  
  test "ET.Transducers.chunk_by(map_fun)" do
    ET.Transducers.chunk_by(&(rem(&1,3)==0))
    |> ET.Reducers.list()
    |> chunk_by_map_fun_test
  end
  
  test "ET.Transducers.chunk_by(transducer, map_fun)" do
    identity_trans
    |> ET.Transducers.chunk_by(&(rem(&1,3)==0))
    |> ET.Reducers.list()
    |> chunk_by_map_fun_test
  end

  defp chunk_by_map_fun_test(reducer) do
    assert ET.reduce(1..4, reducer) == [[1,2],[3],[4]]
  end

  test "ET.Transducers.chunk_by(map_fun, inner_reducer)" do
    ET.Transducers.chunk_by(&(rem(&1,3)==0), ET.Reducers.count())
    |> ET.Reducers.list()
    |> chunk_by_map_fun_inner_reducer_test
  end

  test "ET.Transducers.chunk_by(transducer, map_fun, inner_reducer)" do
    identity_trans
    |> ET.Transducers.chunk_by(&(rem(&1,3)==0), ET.Reducers.count())
    |> ET.Reducers.list()
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

  defp ensure_test(reducer) do
    coll = [1,2,3]
    {:cont, state} = reducer.(:init)
    assert {{:cont, state},  coll} = ET.reduce_step(coll, state, reducer)
    assert {{:halt, state}, _coll} = ET.reduce_step(coll, state, reducer)
    assert {:fin, [1]} = reducer.({:fin, state})
  end

  test "ET.Transducers.map(map_fun)" do
    ET.Transducers.map(&(&1+1))
    |> ET.Reducers.list()
    |> map_map_fun_test
  end

  test "ET.Transducers.map(transducer, map_fun)" do
    identity_trans
    |> ET.Transducers.map(&(&1+1))
    |> ET.Reducers.list()
    |> map_map_fun_test
  end

  defp map_map_fun_test(reducer) do
    assert ET.reduce(1..3, reducer) == [2,3,4]
  end
  
  test "ET.Transducers.take(n)" do
    ET.Transducers.take(3)
    |> ET.Reducers.list()
    |> take_n_test
  end

  test "ET.Transducers.take(transducer, n)" do
    identity_trans
    |> ET.Transducers.take(3)
    |> ET.Reducers.list()
    |> take_n_test
  end

  defp take_n_test(reducer) do
    assert ET.reduce([1], reducer) == [1]
    assert ET.reduce(1..4, reducer) == [1,2,3]
  end
  
  test "ET.Transducers.zip()" do
    ET.Transducers.zip
    |> ET.Reducers.list()
    |> zip_test
  end

  test "ET.Transducers.zip(transducer)" do
    identity_trans
    |> ET.Transducers.zip
    |> ET.Reducers.list()
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
      |> ET.Reducers.list()

    assert ET.reduce([[1,2],[3,4],[5,6]], zip_two) == [1,3]
  end
end
