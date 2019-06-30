# Used by "mix format"
[
  inputs: ["mix.exs", "{lib,test}/**/*.{ex,exs}"],
  import_deps: [:stream_data],
  locals_without_parens: [plug: :*, get: 2, resource: 1, resource: 2],
  export: [locals_without_parens: [resource: 1, resource: 2]]
]
