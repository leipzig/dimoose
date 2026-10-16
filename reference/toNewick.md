# Write a key as Newick, with safe labels or node annotations

The [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
method `$toNewick()` writes quoted Newick, which is correct but which
several parsers (ape, scikit-bio, toytree) mangle. This wrapper adds two
options for interoperating with the wider phylogenetics ecosystem.

## Usage

``` r
toNewick(
  key,
  labels = c("quoted", "safe"),
  annotate = c("none", "nhx", "beast")
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- labels:

  `"quoted"` (the default, identical to `key$toNewick()`) or `"safe"`,
  which replaces every label with an ASCII id (`n<couplet>` for
  couplets, `t<n>` for taxa) and returns the mapping in a side table, so
  fragile parsers never see spaces or punctuation. The real text travels
  in the companion table (this is also the Newick-plus-table shape
  Taxonium reads).

- annotate:

  `"none"` (default), `"nhx"` or `"beast"`: attach each lead's
  `Character` text to the node it leads to, as an NHX
  (`[&&NHX:lead=...]`) or BEAST-style (`[&lead=...]`) comment. Values
  are sanitized (`, : ; = " [ ]` and newlines removed) because Newick
  comments cannot carry them. Only one of `labels = "safe"` or
  `annotate` applies at a time; `annotate` wins if both are given.

  \[ \]: R:%20

## Value

For `labels = "quoted"` or any `annotate`, a single Newick string. For
`labels = "safe"` with `annotate = "none"`, a list of `newick` (the
string) and `labels` (a data frame of `id` and `label`).

## See also

[`toTreedata()`](https://leipzig.github.io/dimoose/reference/toTreedata.md),
[`toAuspiceJSON()`](https://leipzig.github.io/dimoose/reference/toAuspiceJSON.md)

## Examples

``` r
k <- arachnidaKey()
cat(toNewick(k, annotate = "nhx"))
#> ((Araneae[&&NHX:lead=Opisthosoma petiolate (Figures 5-5 and 5-9 through 5-13)],Acari[&&NHX:lead=Opisthosoma not petiolate  but broadly joined to prosoma (Figures 5-15 through 5-22)])2[&&NHX:lead=Opisthosoma (abdomen) unsegmented or  if segmented  with spinnerets posteriorly on ventral side (Figures 5-5 and 5-8  ALS PLS PMS)],((Scorpiones[&&NHX:lead=Opisthosoma ending in a sting (Figure 5-3)  first pair of legs not greatly elongated  second ventral segment of opisthosoma with a pair of comblike organs],(Palpigradi[&&NHX:lead=Pedipalps slender  similar to legs (Figure 5-4A)  minute forms  5 mm or less in length],(Uropygi[&&NHX:lead=With two median eyes on a tubercle anteriorly and a group of three eyes on each lateral margin  tail long  filiform  and many-segmented  pedipalps nearly straight or curved mesad  extending forward  and moving laterally (Figure 5-4B)  body blackish  more than 50 mm in length],Schizomida[&&NHX:lead=Eyes lacking  tail short  one- to four-segmented  pedipalps arching upward  forward  and downward and moving vertically  body yellowish or brownish  less than 8 mm in length])6[&&NHX:lead=Pedipalps usually much stouter than any of the legs (Figure 5-4B)  mostly larger forms])5[&&NHX:lead=Opisthosoma not ending in a sting  first pair of legs longer than other pairs (Figure 5-4A B)  second ventral segment of opisthosoma without comblike organs])4[&&NHX:lead=Opisthosoma with a tail-like prolongation that is either thick and terminating in a sting (Figure 5-3) or slender and more or less whiplike (Figure 5-4A B)  mostly tropical],(Pseudoscorpiones[&&NHX:lead=Pedipalps chelate (pincerlike) (Figure 5-23)  body more or less oval  flattened  usually less than 5 mm in length],(Solifugae[&&NHX:lead=Chelicerae very large  usually about as long as prosoma  and extending forward  and body slightly narrowed in middle (Figure 5-4C)  color pale yellow to brownish  length 20 to 30 mm  mostly nocturnal desert forms occurring in western United States],((Schizomida[&&NHX:lead=Prosoma longer than wide  lateral margins nearly parallel  and with a transverse membranous suture in caudal third  opisthosoma with a very short terminal appendage  length 5-8 mm (see also couplet 6')],Amblypygi[&&NHX:lead=Prosoma wider than long  lateral margins rounded or arched  and without a transverse suture  opisthosoma without a terminal appendage  length variable  up to about 50 mm])10[&&NHX:lead=First pair of legs very long  with long tarsi  opisthosoma constricted at base  mainly tropical],(Ricinulei[&&NHX:lead=Orange-red to brown arachnids  about 3 mm in length  with broad flap at anterior end of prosoma concealing chelicerae  legs not unusually long  animal somewhat mitelike or ticklike in appearance  recorded from Rio Grande Valley of Texas],Opiliones[&&NHX:lead=Size and color variable  but without broad flap at anterior end of prosoma covering chelicerae  legs variable in length  often very long and slender (Figure 5-14)  widely distributed])11[&&NHX:lead=First legs similar to the others and (except in the Opiliones) not usually long  opisthosoma not particularly constricted at base])9[&&NHX:lead=Without the preceding combination of characters])8[&&NHX:lead=Pedipalps raptorial or leglike  but not chelate  body not particularly flattened  size variable])7[&&NHX:lead=Opisthosoma without a tail-like prolongation or with a very short leaflike appendage])3[&&NHX:lead=Opisthosoma distinctly segmented  without spinnerets])1;
```
