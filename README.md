# Hymnody

Builds a website of public domain hymns: https://lutheranhymnody.netlify.com/tlh. The website is not finished (90s underconstruction image here).

`ruby.rb` collected all the words for all the hymns and looked up the word sylables "hello -> hel -- lo" and saved the dictionary for the next step.

`ruby2.rb` converted the input texts into a Lilypond format and converted the input tunes into a nicer format. Tunes have a many to one relation ship with texts, hymn numbers are duplicated, and words have differing pronunciations adding to the complexity.

`Hymnody.build()` is very straightforward:

```
def build do
  clean()
  build_ly()
  build_svg()
  build_indices()
  build_html()
end
```

For testing it can also be called like: `Hymnody.build(["1","10","100"])`. Or just the step needed can be called: `Hymnody.build_indices()`

Lilypond is quite slow to start (~10 seconds), but actually generating the svg is fast (~2 seconds). Lilypond can accept multiple files as input, but crashes if more than ~65 are input on my machine. I can minimize time spent during generation by chunking by 60 to minimize startup time costs like so:

```
|> Stream.map(fn x -> "../ly/" <> x <> ".ly" end)
|> Stream.chunk_every(60)
|> Enum.each(&run_lilypond(&1, svg_path))
```