# Key to the Orders of Arachnida

The key from Triplehorn & Johnson (2005), *Borror and DeLong's
Introduction to the Study of Insects*, 7th ed., chapter 5, as a table of
leads (see
[`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md));
[`arachnidaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
turns it into a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.
Transcribed by hand from the book.

## Usage

``` r
arachnida
```

## Format

A data frame with 22 rows (11 couplets) and 6 columns:

- Statement:

  Couplet number.

- Choice:

  `a` for the first lead (`1.`), `b` for the second (`1'.`).

- Character:

  Text of the lead.

- Next:

  Couplet the lead leads to, or `"-"`.

- Taxon:

  Order the lead ends in, for terminal leads.

- Page:

  Page of the book where that order is treated.

## Source

Triplehorn CA, Johnson NF (2005). *Borror and DeLong's Introduction to
the Study of Insects*, 7th ed. Thomson Brooks/Cole. Transcription:
`data-raw/arachnida/` in the package sources.
