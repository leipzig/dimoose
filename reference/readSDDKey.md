# Read and write a dichotomous key stored in SDD

Besides character matrices, an SDD file can hold ready-made
identification keys (`<IdentificationKey>` elements): a tree of leads,
each with a statement and either further leads, a taxon or a pointer to
another key in the file. `readSDDKey()` reads one into a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key,
`writeSDDKey()` stores a dimoose key that way. Lucid's pathway-key
builder exports this form.

## Usage

``` r
readSDDKey(file, key = 1, desc = NULL, dataset = NULL)

writeSDDKey(key, file, title = NULL, lang = "en")
```

## Arguments

- file:

  Path of the SDD file.

- key:

  For `readSDDKey()`, which key of the file to read: its position or its
  `id`. For `writeSDDKey()`, the
  [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
  to write.

- desc:

  Title of the key; by default the key's label in the file.

- dataset:

  Which `<Dataset>` of the file to read, by position; by default the
  first one that holds a key.

- title:

  Title of the SDD dataset; by default the key's description.

- lang:

  Language of the text, as an `xml:lang` code.

## Value

`readSDDKey()` returns a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key;
`writeSDDKey()` returns `file`, invisibly.

## Details

In SDD the leads form a tree (each lead names its parent lead) and are
not numbered. On reading, the leads that share a parent become a couplet
and the couplets are numbered in the usual order of a printed key (the
first lead of couplet 1 goes to couplet 2, and so on). A lead that
points to another key of the same file (`<Subkey>`) continues with that
key's first couplet, so a key split over several SDD keys comes back as
one. A question on a lead (or on the key itself) becomes the `Question`
of the couplet it leads to. A lead that ends without a taxon is kept,
and reported by `key$validate()`.

On writing, a couplet that is reached from more than one lead (a
reticulate key) is written out once under each of them, because an SDD
lead can have only one parent. Images and links attached to leads or
taxa (`Image`, `TaxonUrl`) and other extra columns of the key are not
written.

## See also

[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
for the character matrix of an SDD file,
[`readLucidKey()`](https://leipzig.github.io/dimoose/reference/readLucidKey.md)
for Lucid's own pathway-key formats.

## Examples

``` r
f <- system.file("extdata", "tdwg", "insects-key.sdd.xml", package = "dimoose")
k <- readSDDKey(f)
k
#> <dimoose key> Key to some orders of insects
#>   4 couplets, 8 leads, 5 taxa, up to 3 steps deep (2.4 on average)
k$leads[, c("Statement", "Choice", "Character", "Next", "Taxon")]
#>   Statement Choice                                                  Character
#> 1         1      a                                               Wings absent
#> 2         1      b                                              Wings present
#> 3         2      a     Body flattened from side to side, 1-2 mm long; jumping
#> 4         2      b Body flattened from above, 10-15 mm long, with three tails
#> 5         3      a                                       Forewings membranous
#> 6         3      b         Forewings hard covers that meet in a straight line
#> 7         4      a                           Hindwings reduced to small knobs
#> 8         4      b      Hindwings present; wings and body covered with scales
#>   Next        Taxon
#> 1    2             
#> 2    3             
#> 3    - Siphonaptera
#> 4    -    Zygentoma
#> 5    4             
#> 6    -   Coleoptera
#> 7    -      Diptera
#> 8    -  Lepidoptera

out <- writeSDDKey(sharkKey(), tempfile(fileext = ".xml"))
readSDDKey(out)
#> <dimoose key> Key to the families of sharks in the Western Central Pacific.
#>   23 couplets, 46 leads, 24 taxa, up to 12 steps deep (7.5 on average)
```
