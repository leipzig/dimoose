# Score aligned sequences against a key built from an alignment

Computes the tests of a
[`keyFromAlignment()`](https://leipzig.github.io/dimoose/reference/keyFromAlignment.md)
key for each sequence, for
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md).
The sequences must be aligned to the same coordinates the key was built
with: the same alignment columns or, for a key built with a `reference`,
an alignment that contains that reference sequence.

## Usage

``` r
alignmentScores(key, alignment, reference = NULL)
```

## Arguments

- key:

  A key from
  [`keyFromAlignment()`](https://leipzig.github.io/dimoose/reference/keyFromAlignment.md).

- alignment:

  As in
  [`keyFromAlignment()`](https://leipzig.github.io/dimoose/reference/keyFromAlignment.md).

- reference:

  Sequence to number sites by; by default the reference the key was
  built with, if any.

## Value

A `sequences x features` matrix: 1 if the sequence has the state the
first lead of a couplet asks for, 0 if it has another state, and `NA` if
it has a gap or an ambiguity code there.
