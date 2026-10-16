# Build a key by clustering classes and describing each split

Classes are clustered on the mean embedding of their images (Ward's
method), giving a binary tree. Each split is then described by the
vocabulary pair that best separates its two sides: the pair maximising
\|(L.yes - L.no) - (R.yes - R.no)\| over the side means, not used above
that split. The "Has feature" lead goes to the side the feature scores
higher on. Machine answers use the same two prompts.

## Usage

``` r
keyFromClusters(
  image,
  images,
  vocabulary,
  textEmb,
  template = "{x}",
  order = NULL,
  maxPerSide = 10,
  calibrate = c("none", "midpoint"),
  desc = "Key generated from image clusters",
  meta = NULL
)
```

## Arguments

- image:

  `images x d` matrix of unit-length image embeddings.

- images:

  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  data frame, one row per row of `image`.

- vocabulary:

  As in
  [`vocabularyPrompts()`](https://leipzig.github.io/dimoose/reference/vocabularyPrompts.md).

- textEmb:

  Text embeddings of `vocabularyPrompts(vocabulary, template)`, rows
  named by prompt (as
  [`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
  returns them).

- template:

  Must match the one used to make `textEmb`.

- order:

  Optional function of a character vector of labels returning a number;
  at each split the child with the smaller value comes first.

- maxPerSide:

  Most images per side used for the side means.

- calibrate:

  `"none"` (threshold 0) or `"midpoint"` (halfway between the two sides'
  mean scores).

- desc, meta:

  Title and metadata.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
with `clip_text_pair` features.
