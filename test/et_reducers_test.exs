defmodule ETReducersTest do
  use ExUnit.Case

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "all?()" do
    all_test(ET.Reducers.all?)
  end

  test "all?(transducer)" do
    all_test(identity_trans |> ET.Reducers.all?)
  end

  defp all_test (reducer) do
    assert ET.reduce([1, true], reducer) == true
    assert ET.reduce([true, false, true], reducer) == false
    assert ET.reduce([true, nil, true], reducer) == false
  end

  test "all?(check_fun)" do
    all_check_fun_test(ET.Reducers.all?(&(&1<4)))
  end

  test "all?(transducer, check_fun)" do
    all_check_fun_test(identity_trans |> ET.Reducers.all?(&(&1<4)))
  end

  defp all_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([1,2,3,4], reducer) == false
  end

  test "any?()" do
    any_test(ET.Reducers.any?())
  end

  test "any?(transducer)" do
    any_test(identity_trans |> ET.Reducers.any?())
  end

  defp any_test(reducer) do
    assert ET.reduce([false, true], reducer) == true
    assert ET.reduce([false, 1], reducer) == true
    assert ET.reduce([false, nil], reducer) == false
  end

  test "any?(check_fun)" do
    any_check_fun_test(ET.Reducers.any?(&(&1<2)))
  end

  test "any?(transducer, check_fun)" do
    any_check_fun_test(identity_trans |> ET.Reducers.any?(&(&1<2)))
  end

  defp any_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([2,3,4], reducer) == false
  end

  test "count()" do
    count_test(ET.Reducers.count)
  end

  test "count(transducer)" do
    count_test(identity_trans |> ET.Reducers.count)
  end

  defp count_test(reducer) do
    assert ET.reduce([], reducer) == 0
    assert ET.reduce(1..3, reducer) == 3
    assert ET.reduce(1..4, reducer) == 4
  end
  
  test "list reducer" do
    assert ET.reduce([1,2,3,4], ET.Reducers.list) == [1,2,3,4]
    assert ET.reduce([1,2,3,4], (ET.Transducers.take(2) |> ET.Reducers.list)) == [1,2]
  end
end
