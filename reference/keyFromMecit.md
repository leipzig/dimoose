# Turn a mixed-effects tree into a key

Each split becomes a couplet and each terminal node a result, labelled
with its stratum level and size. Splits on 0/1 variables read as
"Carries 16311" / "Does not carry 16311". The leads carry
machine-readable tests on the split variables, so
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
can place new samples given their
[`haplotypeMatrix()`](https://leipzig.github.io/dimoose/reference/haplotypeMatrix.md),
and
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
can draw the tree. Splits on factor columns become text-only couplets
("tissue is liver or lung"), which a person can follow but
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
cannot; the function warns when the key has any.

## Usage

``` r
keyFromMecit(fit, desc = NULL, digits = 2)
```

## Arguments

- fit:

  A [`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md)
  fit.

- desc:

  Title of the key.

- digits:

  Decimal places for stratum levels.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.
