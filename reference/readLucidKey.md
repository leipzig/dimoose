# Read and write Lucid pathway (dichotomous) keys

The Lucid Builder also makes "pathway" keys: ordinary dichotomous keys
of couplets and leads (the successor of the stand-alone Lucid Phoenix).
`readLucidKey()` reads one of its exports into a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
and `writeLucidKey()` writes a dimoose key in the same forms. All four
are described in the Lucid Builder help ("Pathway key exports"):

## Usage

``` r
readLucidKey(file, format = NULL, desc = NULL)

writeLucidKey(key, file, format = c("lpxk", "csv", "text", "sdd"))
```

## Arguments

- file:

  Path of the file to read or write.

- format:

  `"lpxk"`, `"csv"`, `"text"` or `"sdd"`; when reading, by default
  worked out from the file.

- desc:

  Title of the key; by default the title in the file, if any.

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

## Value

`readLucidKey()` returns a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key;
`writeLucidKey()` returns `file`, invisibly.

## Details

- **`"lpxk"`**, Lucid Phoenix XML: `<PhoenixKey>` with the taxa as
  `<Identity>` elements and the couplets as `<Step>` elements holding
  `<Lead>`s whose `goto` names the next step or the taxon. The step's
  `text` becomes the couplet's `Question`, an identity's `url` the
  `TaxonUrl`. Filters (`<FilterItem>`) and icons are not read or
  written.

- **`"csv"`**: one line per lead,
  `couplet,"lead text",next couplet or taxon`.

- **`"text"`**: the same with blanks instead of commas, as printed in a
  paper.

- **`"sdd"`**: SDD with an identification key; see
  [`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md).

In the CSV and text forms the last field is read as a couplet when it
matches a couplet number and as a taxon otherwise, so `writeLucidKey()`
refuses to write a key in which a taxon is named like a couplet. These
two forms hold neither the title of the key nor questions, links or
images. The CSV, text and Phoenix XML forms follow the examples printed
in the Lucid help; no file exported by the Lucid Builder itself was
available to check them against, and no file written by dimoose has been
imported into the Builder.

## References

Lucid Builder help, "Pathway key exports",
<https://help.lucidcentral.org/lucid/pathway-key-exports/>.

## See also

[`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
for Lucid matrix keys,
[`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md),
[`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md).

## Examples

``` r
f <- system.file("extdata", "tdwg", "insects.lpxk", package = "dimoose")
k <- readLucidKey(f)
k
#> <dimoose key> Some orders of insects
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

out <- writeLucidKey(k, tempfile(fileext = ".csv"), format = "csv")
readLines(out)
#> [1] "1,\"Wings absent\",2"                                                      
#> [2] "1,\"Wings present\",3"                                                     
#> [3] "2,\"Body flattened from side to side, 1-2 mm long; jumping\",Siphonaptera" 
#> [4] "2,\"Body flattened from above, 10-15 mm long, with three tails\",Zygentoma"
#> [5] "3,\"Forewings membranous\",4"                                              
#> [6] "3,\"Forewings hard covers that meet in a straight line\",Coleoptera"       
#> [7] "4,\"Hindwings reduced to small knobs\",Diptera"                            
#> [8] "4,\"Hindwings present; wings and body covered with scales\",Lepidoptera"   
```
