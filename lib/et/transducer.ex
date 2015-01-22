defmodule ET.Transducer do
  defstruct elements: []

  def compose(%ET.Transducer{elements: [transducer | rest]}, reducer) do
    compose(%ET.Transducer{elements: rest}, transducer.(reducer))
  end
  def compose(%ET.Transducer{elements: []}, reducer), do: reducer

  def combine(%ET.Transducer{elements: t1}, %ET.Transducer{elements: [t2]}) do
    %ET.Transducer{elements: [t2 | t1]}
  end
  def combine(%ET.Transducer{elements: t1}, %ET.Transducer{elements: t2}) do
    %ET.Transducer{elements: t2 ++ t1}
  end
end
