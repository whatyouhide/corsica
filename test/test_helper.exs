if Code.ensure_loaded?(ExUnitProperties) do
  Application.ensure_all_started(:stream_data)
  ExUnit.configure(exclude: ExUnit.configuration()[:exclude] ++ [:replaced_by_property])
end

ExUnit.start()
