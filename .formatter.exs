# Used by "mix format"
[
  inputs: ["mix.exs", "{lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [plug: :*, get: 2, resource: 1, resource: 2],
  export: [locals_without_parens: [resource: 1, resource: 2]]
]
