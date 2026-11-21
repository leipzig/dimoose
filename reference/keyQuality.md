# How quickly a key gets to a result

Counts the steps (couplets answered) it takes to reach each result of a
key and compares the average with the fewest steps any key could need.

## Usage

``` r
keyQuality(key, weights = NULL)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- weights:

  How common each taxon is: a numeric vector whose names are the key's
  results as written in its `Taxon` column, such as the output of
  [`occurrenceWeights()`](https://leipzig.github.io/dimoose/reference/occurrenceWeights.md).
  They need not sum to 1, and names that are not in the key are ignored.
  Taxa that are missing from it or `NA` count as 0, with a warning. A
  vector without names is an error, as is a name that is there twice.
  `NULL` (the default) treats all taxa as equally common.

## Value

A list with

- `taxa`: a data frame with one row per taxon: `Taxon`, `leads` (how
  many terminal leads end in it), `steps` (mean over those leads),
  `minSteps`, `maxSteps` and `weight` (its share of the weights, summing
  to 1);

- `leads`: a data frame with one row per terminal lead: `Lead` (its
  label, e.g. `"7b"`), `Statement`, `Choice`, `Taxon` and `steps`;

- `meanLeadSteps`: mean steps over terminal leads;

- `meanTaxonSteps`: mean steps over taxa;

- `expectedSteps`: mean steps over taxa weighted by `weight` (the same
  as `meanTaxonSteps` without `weights`);

- `bound`: the expected steps of the best possible key to these taxa
  with these weights and couplets of at most `maxLeads` leads;

- `efficiency`: `bound / expectedSteps`, above 0 and at most 1 (`NA` for
  a key to a single taxon, which needs no steps);

- `entropy`: the Shannon entropy of `weight`, in bits;

- `bitsPerStep`: the most a step of this key can tell, on average (1
  when every couplet has two leads);

- `capacityUsed`: `entropy / (bitsPerStep * expectedSteps)`, at most 1;

- `maxLeads`: the number of leads in the key's largest couplet;

- `depth`: the longest route to a result, in steps.

## Details

A key is a code: each result is spelled by the leads chosen on the way
to it. `bound` is the expected number of steps of the best key there
could be for the same taxa and the same `weights`, among keys whose
couplets have no more leads than the largest couplet of this key
(`maxLeads`). It is found by Huffman's construction, which joins the
rarest taxa first, so it is a number of steps that a key can really
reach: 3 for eight equally common taxa and couplets of two leads, about
3.55 for eleven. No key can do better, however its characters are
chosen. `efficiency` is `bound / expectedSteps`: 1 for a key that could
not be shorter, and lower the more steps the key takes than it would
have to. Real keys rarely reach 1, because the characters that would
split the taxa evenly may not exist.

When some taxa are met more often than others (`weights`), a good key
asks few questions before reaching the common ones, and the bound takes
the weights into account in the same way.

In a key that has a few large couplets among many small ones (a
PhyloTree key has couplets of 2 and of 87 leads), the best key is
allowed the largest couplet everywhere, so the bound is far below what
the key does and `efficiency` is low. Three more numbers describe such
keys without that comparison. `entropy` is the Shannon entropy of the
weights in bits (`log2` of the number of taxa when they are equally
common): the information a key has to gather. A couplet with `k` leads
can give up to `log2(k)` bits, and `bitsPerStep` is the average of that
over the steps this key takes (1 for a key of two-lead couplets).
`capacityUsed` is `entropy / (bitsPerStep * expectedSteps)`: the share
of the information its couplets could give that the key needs. It is 1
when every couplet splits what reaches it evenly, whatever its size, and
it is not a comparison with a shorter key.

Two cases need a rule:

- A taxon that keys out at several terminal leads counts once: its steps
  are the mean over its leads, as if its specimens were split evenly
  among them, and its weight is not multiplied by the number of leads.

- A couplet reached from several leads (a reticulate key) is counted by
  its shortest route from the first couplet, so `steps` is the fewest
  steps in which a result can be reached. `depth` is the longest route.

Leads in couplets that cannot be reached from the first couplet, and
terminal leads that name no taxon, are left out of the averages.

## See also

[`summary()`](https://rdrr.io/r/base/summary.html) on a key, which
reports the aggregates;
[`occurrenceWeights()`](https://leipzig.github.io/dimoose/reference/occurrenceWeights.md)
for weights from GBIF.

## Examples

``` r
q <- keyQuality(arachnidaKey())
q$taxa
#>               Taxon leads steps minSteps maxSteps     weight
#> 1           Araneae     1   2.0        2        2 0.09090909
#> 2             Acari     1   2.0        2        2 0.09090909
#> 3        Scorpiones     1   3.0        3        3 0.09090909
#> 4        Palpigradi     1   4.0        4        4 0.09090909
#> 5           Uropygi     1   5.0        5        5 0.09090909
#> 6        Schizomida     2   5.5        5        6 0.09090909
#> 7  Pseudoscorpiones     1   3.0        3        3 0.09090909
#> 8         Solifugae     1   4.0        4        4 0.09090909
#> 9         Amblypygi     1   6.0        6        6 0.09090909
#> 10        Ricinulei     1   6.0        6        6 0.09090909
#> 11        Opiliones     1   6.0        6        6 0.09090909
q$expectedSteps
#> [1] 4.227273
q$bound
#> [1] 3.545455
q$efficiency
#> [1] 0.8387097

# spiders and mites are met far more often than the other orders
common <- c(Araneae = 50, Acari = 40, Opiliones = 5, Scorpiones = 3)
suppressWarnings(keyQuality(arachnidaKey(), common))$expectedSteps
#> [1] 2.234694
```
