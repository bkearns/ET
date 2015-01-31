defmodule ETReducersTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "all?()" do
    ET.Reducers.all?
    |> all_test
  end

  test "all?(transducer)" do
    identity_trans
    |> ET.Reducers.all?
    |> all_test
  end

  defp all_test (reducer) do
    assert ET.reduce([1, true], reducer) == true
    assert ET.reduce([true, false, true], reducer) == false
    assert ET.reduce([true, nil, true], reducer) == false
  end

  test "all?(check_fun)" do
    ET.Reducers.all?(&(&1<4))
    |> all_check_fun_test
  end

  test "all?(transducer, check_fun)" do
    identity_trans
    |> ET.Reducers.all?(&(&1<4))
    |> all_check_fun_test
  end

  defp all_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([1,2,3,4], reducer) == false
  end

  test "any?()" do
    ET.Reducers.any?
    |> any_test
  end

  test "any?(transducer)" do
    identity_trans
    |> ET.Reducers.any?()
    |> any_test
  end

  defp any_test(reducer) do
    assert ET.reduce([false, true], reducer) == true
    assert ET.reduce([false, 1], reducer) == true
    assert ET.reduce([false, nil], reducer) == false
  end

  test "any?(check_fun)" do
    ET.Reducers.any?(&(&1<2))
    |> any_check_fun_test
  end

  test "any?(transducer, check_fun)" do
    identity_trans
    |> ET.Reducers.any?(&(&1<2))
    |> any_check_fun_test
  end

  defp any_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([2,3,4], reducer) == false
  end

  test "count()" do
    ET.Reducers.count
    |> count_test
  end

  test "count(transducer)" do
    identity_trans
    |> ET.Reducers.count
    |> count_test
  end

  defp count_test(reducer) do
    assert ET.reduce([], reducer) == 0
    assert ET.reduce(1..3, reducer) == 3
    assert ET.reduce(1..4, reducer) == 4
  end
  
  test "list()" do
    ET.Reducers.list
    |> list_test
  end

  test "list(transducer)" do
    identity_trans
    |> ET.Reducers.list
    |> list_test
  end

  defp list_test(reducer) do
    assert ET.reduce([1,2,3,4], reducer) == [1,2,3,4]
  end
end
