# Used by "mix format"
export_locals_without_parens = [plug: :*, resource: :*, get: 2]

[
  inputs: ["mix.exs", "{lib,test}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
