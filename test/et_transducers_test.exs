defmodule ETTransducersTest do
  use ExUnit.Case

  defp identity_trans, do: ET.Transducers.map(&(&1))
  
  test "ET.Transducers.chunk(size)" do
    chunker = ET.Transducers.chunk(2) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4]]

    chunker = identity_trans |> ET.Transducers.chunk(2) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4]]
  end

  test "ET.Transducers.chunk(size, step)" do
    chunker = ET.Transducers.chunk(2,1) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [[1,2], [2,3], [3,4]]

    chunker = identity_trans |> ET.Transducers.chunk(2,1) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [[1,2], [2,3], [3,4]]
  end

  test "ET.Transducers.chunk(size, inner_reducer)" do
    chunker = ET.Transducers.chunk(2, ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [2, 2]

    chunker = identity_trans |> ET.Transducers.chunk(2, ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [2, 2]
  end

  test "ET.Transducers.chunk(size, padding)" do
    chunker = ET.Transducers.chunk(2, [:a, :b, :c]) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4], [5,:a]]

    chunker = identity_trans |> ET.Transducers.chunk(2, [:a, :b, :c]) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4], [5,:a]]
  end

  test "ET.Transducers.chunk(size, empty_padding)" do
    chunker = ET.Transducers.chunk(2, []) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4], [5]]

    chunker = identity_trans |> ET.Transducers.chunk(2, []) |> ET.Reducers.list()
    assert ET.reduce(1..5, chunker) == [[1,2], [3,4], [5]]
  end

  test "ET.Transducers.chunk(size, step, padding)" do
    chunker = ET.Transducers.chunk(2, 1, [:a]) |> ET.Reducers.list()
    assert ET.reduce(1..3, chunker) == [[1,2], [2,3], [3,:a]]

    chunker = identity_trans |> ET.Transducers.chunk(2, 1, [:a]) |> ET.Reducers.list()
    assert ET.reduce(1..3, chunker) == [[1,2], [2,3], [3,:a]]
  end

  test "ET.Transducers.chunk(size, step, inner_reducer)" do
    chunker = ET.Transducers.chunk(2, 1, ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [2, 2, 2]

    chunker = identity_trans |> ET.Transducers.chunk(2, 1, ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [2, 2, 2]
  end

  test "ET.Transducers.chunk(size, step, padding, inner_reducer)" do
    chunker = ET.Transducers.chunk(2, 1, [:a], ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..3, chunker) == [2, 2, 2]

    chunker = identity_trans |> ET.Transducers.chunk(2, 1, [:a], ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..3, chunker) == [2, 2, 2]
  end
  #TODO test early :halt timing and order for inner reducer
  #TODO test generic chunk  

  test "ET.Transducers.chunk_by()" do
    chunker = ET.Transducers.chunk_by() |> ET.Reducers.list()
    assert ET.reduce([1,2,2,3,2], chunker) == [[1],[2,2],[3],[2]]

    chunker = identity_trans |> ET.Transducers.chunk_by() |> ET.Reducers.list()
    assert ET.reduce([1,2,2,3,2], chunker) == [[1],[2,2],[3],[2]]
  end

  test "ET.Transducers.chunk_by(map_fun)" do
    chunker = ET.Transducers.chunk_by(&(rem(&1,3)==0)) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [[1,2],[3],[4]]

    chunker = identity_trans |> ET.Transducers.chunk_by(&(rem(&1,3)==0)) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [[1,2],[3],[4]]
  end

  test "ET.Transducers.chunk_by(map_fun, inner_reducer)" do
    chunker = ET.Transducers.chunk_by(&(rem(&1,3)==0), ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [2,1,1]    

    chunker = identity_trans |> ET.Transducers.chunk_by(&(rem(&1,3)==0), ET.Reducers.count()) |> ET.Reducers.list()
    assert ET.reduce(1..4, chunker) == [2,1,1]    
  end

  test "ET.Transducers.ensure" do
    ensure_list = ET.Transducers.ensure(2)
                  |> ET.Transducers.take(1)
                  |> ET.Reducers.list
    coll = [1,2,3]
    {:cont, state} = ensure_list.(:init)
    assert {{:cont, state},  coll} = ET.reduce_step(coll, state, ensure_list)
    assert {{:halt, state}, _coll} = ET.reduce_step(coll, state, ensure_list)
    assert {:fin, [1]} = ensure_list.({:fin, state})
  end
  
  test "ET.Transducers.map" do
    inc_list =
      ET.Transducers.map(fn input -> input + 1 end)
      |> ET.Reducers.list()
    assert ET.reduce([1,2,3], inc_list) == [2,3,4]
  end

  test "ET.Transducers.take" do
    take_three = ET.Transducers.take(3) |> ET.Reducers.list()
    assert ET.reduce([1,2,3,4], take_three) == [1,2,3]
  end
  
  test "ET.Transducers.zip" do
    zip_reducer =
      ET.Transducers.zip
      |> ET.Reducers.list()
    assert ET.reduce([[1,2,3,4], [8, 9]], zip_reducer) ==
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
