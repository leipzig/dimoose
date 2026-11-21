# Build a dimoose key from a character matrix

Generates a dichotomous key from a taxon-by-character matrix, the form
most identification data is kept in (DELTA, Lucid, SDD, a spreadsheet of
test results). Unlike a classification tree, the key is built the way a
person writes one: a taxon that is variable for a character is keyed out
down both leads of every couplet that uses the character.

## Usage

``` r
keyFromMatrix(
  matrix,
  taxon = "Taxon",
  characters = NULL,
  season = NULL,
  variable = c("both", "missing"),
  desc = "Key generated from a character matrix",
  meta = NULL,
  maxCouplets = 10000
)
```

## Arguments

- matrix:

  A character matrix: a data frame with one row per taxon (see 'The
  matrix'), e.g. the `matrix` of
  [`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md)
  or
  [`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md).

- taxon:

  Name of the column holding the taxon names.

- characters:

  Optional data frame of character metadata with a column `Character`
  (matching column names of `matrix`) and any of `Cost` (positive
  number, lower means easier to observe; missing or blank means 1),
  `Season` (seasons or conditions in which the character can be
  observed, separated by `,`, `;` or `/`; blank, `"all"`, `"all year"`
  or `"always"` means always), `Needs` (free text such as `"hand lens"`,
  copied to the leads), `Type` (see 'Numbers and ranges') and
  `InapplicableIf` (see 'How the key is built'). The `characters` table
  of
  [`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md),
  [`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
  [`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
  or
  [`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md)
  can be passed as it is. Characters not listed cost 1 and can always be
  observed; rows for characters that are not in `matrix` are ignored
  (with a warning if no row matches). If a character has several rows
  the first is used, with a warning.

- season:

  Optional character vector. Only characters whose `Season` is blank or
  includes one of these (ignoring case) are used, e.g.
  `season = "winter"` for a bark and twig key.

- variable:

  `"both"` (default) sends a variable taxon down both leads; `"missing"`
  treats variable cells as unknown and fits a classification tree.

- desc:

  Title of the key.

- meta:

  Key/value metadata data frame.

- maxCouplets:

  For `variable = "both"`: give up with an error once the key has more
  couplets than this (see 'Size of the key').

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object. With `variable = "both"` its leads also carry `Question` (the
character's name), `MatrixCharacter` and `MatrixStates` (the character
and the `/`-separated states the lead accepts) and, if `characters` has
it, `Needs`.

## The matrix

A plain data frame (or a character matrix with column names) with one
row per taxon: a taxon column and one column per character. Cells are
state strings (anything else is converted with
[`as.character()`](https://rdrr.io/r/base/character.html)). A taxon that
is variable (polymorphic) for a character lists its states separated by
`/`, e.g. `"+/-"` or `"red/white"`. `NA` or an empty cell means unknown
or inapplicable. If a taxon has several rows, they are merged and the
taxon takes every state seen in any of them. Characters with fewer than
two states among the taxa are dropped. Every column other than `taxon`
is taken as a character, so leave out columns of notes.

## Numbers and ranges

A key can only ask about states a specimen either shows or does not, so
a measurement is used through the ranges that do not overlap. In a
column whose cells are all numbers or ranges, as the readers
[`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md),
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
[`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
and
[`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md)
write them (`"3"`, `"4-6"`, `"(1-)2-8(-12)"`, taken from the lowest to
the highest number in the cell), ranges that overlap or touch are merged
into one state named by its extremes: `"3-5"`, `"5-7"` and `"12-20"`
give the two states `"3-7"` and `"12-20"`. A character whose ranges all
overlap has one state and is dropped. A message says what was merged or
dropped. The cells may end in a unit if it is the same in every cell of
the column (`"2-8 mm"`, `"5-12 mm"`). Negative numbers are not
understood (a `-` is read as "to"). To key a taxon out on part of an
overlapping range, cut the measurement into classes yourself and enter
the classes as states (`"3/5"` and `"5/7"` leaflets in the example
below).

If `characters` has a column `Type`, as the tables of those readers do,
characters of type `"text"` are not used, the rule above applies to
`"integer"` and `"real"` characters only, and `"categorical"` and
`"ordered"` characters are always taken as states.

## How the key is built (`variable = "both"`)

Every couplet tests one state of one character against the rest: the
first lead reads `"Character: state"`, the second
`"Character: other or another"`, naming the other states the taxa still
in play may show. A character with three or more states is therefore
keyed out over several couplets, and every couplet has exactly two
leads.

A taxon follows the first lead if it can show the state and the second
if it can show any other state not already ruled out, so a variable
taxon follows both. So does a taxon whose state is unknown (`NA`), since
it cannot be ruled out on either side. The guarantee is: whichever of
its states a specimen shows for each character, following the key ends
at a result that names its taxon.

At each step the couplet is chosen like this. For every state of every
character, count the taxa that follow the first lead only (`a`) and the
second lead only (`b`). The couplet separates `a * b` pairs of taxa;
taxa that follow both leads separate nothing. The split with the largest
`a * b / Cost` is taken; ties go to the character that comes first in
the matrix, then to the state that appears first in its column. With no
`Cost`, every character costs 1. A character with `Cost` 2 is thus
chosen over one with `Cost` 1 only if it separates more than twice as
many pairs.

If no split separates a pair, the taxa that are left overlap: one shows
`"+"` and another `"+/-"`, or one has 3 to 5 leaflets and another 5 to
7. A couplet can still rule taxa out on one side (`"-"` can only be the
second taxon), so the split with the largest `(a + b) / Cost` is taken,
provided some taxon is known to show the state and some taxon is known
to show another. When no such split is left either, the remaining taxa
share a result, written `"A / B"`: with the states observed they cannot
be told apart.

A group of taxa that is reached by several routes with the same states
still open is keyed out once, and couplets that come out the same lead
for lead are merged, so a couplet may be the target of more than one
lead, and a variable taxon appears at more than one result.

If `characters` has a column `InapplicableIf` (`"Other character=state"`
or `"Other character=state/state"`, several rules separated by `;`, as
written by
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
and
[`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md)),
a character is not asked about while a taxon still in play may show one
of those states of the other character: the key asks whether there is an
aerial stem before it asks whether the stem is hairy. The rule is
dropped where it would leave no couplet at all.

## Size of the key

Because variable and unknown taxa follow both leads, the key grows with
the number of such cells. Random two-state matrices of 200 taxa and 60
characters gave 199 couplets with no unknown cells, about 550 with 30%
unknown and about 3400 with 50%. A matrix in which most characters are
known for only a few taxa can need a number of couplets that doubles
with every character; `maxCouplets` stops such a key with an error
rather than running out of memory, and a key with more than ten couplets
per taxon comes with a warning. Leave out the characters that are
unknown for most taxa, or use `variable = "missing"`.

## `variable = "missing"`

Variable cells are treated as unknown and the key is the classification
tree fitted by
[`rpart::rpart()`](https://rdrr.io/pkg/rpart/man/rpart.html) (through
[`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)),
with `Cost` passed as rpart's `cost`. Each taxon then appears at one
result, but rpart places a taxon it has no state for with surrogate
splits, so a specimen showing the taxon's other state is keyed out
wrongly. A taxon rpart cannot place at a split at all is listed at every
result below that split (a message says how many such taxa there are).
The key is smaller; use it when that matters more than the guarantee
above. A lead may name several states (`"Colour: red,white"`).
`InapplicableIf` is not used.

## See also

[`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md),
[`vibrioMatrix()`](https://leipzig.github.io/dimoose/reference/vibrioMatrix.md),
[`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md),
[`generateTree()`](https://leipzig.github.io/dimoose/reference/generateTree.md)

## Examples

``` r
# Some of Montana's broadleaf trees (see montanaKey() for the key written
# by hand). Box elder has 3 to 5 leaflets and green ash 5 to 7, so a leaf
# with 5 could be either.
trees <- data.frame(
  Taxon = c("Box elder", "Green ash", "Rocky Mountain maple", "Bur oak",
            "Quaking aspen", "Paper birch", "Water birch"),
  `Buds and leaves` = c("opposite", "opposite", "opposite", "alternate",
                        "alternate", "alternate", "alternate"),
  `Leaf type` = c("compound", "compound", "simple", "simple", "simple",
                  "simple", "simple"),
  Leaflets = c("3/5", "5/7", NA, NA, NA, NA, NA),
  `Leaf lobes` = c(NA, NA, "lobed", "lobed", "not lobed", "not lobed",
                   "not lobed"),
  Bark = c(NA, NA, NA, NA, "smooth and pale", "white and peeling",
           "gray to brown"),
  check.names = FALSE
)
k <- keyFromMatrix(trees, desc = "Some Montana trees")
k$leads[c("Statement", "Choice", "Character", "Next", "Taxon")]
#>    Statement Choice                                Character Next
#> 1          1      a                Buds and leaves: opposite    2
#> 2          1      b               Buds and leaves: alternate    5
#> 3          2      a                      Leaf type: compound    3
#> 4          2      b                        Leaf type: simple    -
#> 5          3      a                              Leaflets: 3    -
#> 6          3      b                         Leaflets: 5 or 7    4
#> 7          4      a                              Leaflets: 5    -
#> 8          4      b                              Leaflets: 7    -
#> 9          5      a                        Leaf lobes: lobed    -
#> 10         5      b                    Leaf lobes: not lobed    6
#> 11         6      a                    Bark: smooth and pale    -
#> 12         6      b Bark: white and peeling or gray to brown    7
#> 13         7      a                  Bark: white and peeling    -
#> 14         7      b                      Bark: gray to brown    -
#>                    Taxon
#> 1                       
#> 2                       
#> 3                       
#> 4   Rocky Mountain maple
#> 5              Box elder
#> 6                       
#> 7  Box elder / Green ash
#> 8              Green ash
#> 9                Bur oak
#> 10                      
#> 11         Quaking aspen
#> 12                      
#> 13           Paper birch
#> 14           Water birch

# Leaves are easy to see but only there in summer; bud arrangement needs a
# closer look but works all year
characters <- data.frame(
  Character = c("Buds and leaves", "Leaf type", "Leaflets", "Leaf lobes", "Bark"),
  Cost = c(2, 1, 1, 1, 1),
  Season = c("", "summer", "summer", "summer", ""),
  Needs = c("a twig in the hand", "", "", "", "")
)
keyFromMatrix(trees, characters = characters)$leads$Character
#>  [1] "Leaf type: compound"                     
#>  [2] "Leaf type: simple"                       
#>  [3] "Leaflets: 3"                             
#>  [4] "Leaflets: 5 or 7"                        
#>  [5] "Leaflets: 5"                             
#>  [6] "Leaflets: 7"                             
#>  [7] "Leaf lobes: lobed"                       
#>  [8] "Leaf lobes: not lobed"                   
#>  [9] "Buds and leaves: opposite"               
#> [10] "Buds and leaves: alternate"              
#> [11] "Bark: smooth and pale"                   
#> [12] "Bark: white and peeling or gray to brown"
#> [13] "Bark: white and peeling"                 
#> [14] "Bark: gray to brown"                     

# A winter key: what bark and buds cannot separate shares a result
winter <- keyFromMatrix(trees, characters = characters, season = "winter")
winter$leads[c("Character", "Taxon")]
#>                                  Character
#> 1                Buds and leaves: opposite
#> 2               Buds and leaves: alternate
#> 3                    Bark: smooth and pale
#> 4 Bark: white and peeling or gray to brown
#> 5                  Bark: white and peeling
#> 6                      Bark: gray to brown
#>                                          Taxon
#> 1 Box elder / Green ash / Rocky Mountain maple
#> 2                                             
#> 3                      Bur oak / Quaking aspen
#> 4                                             
#> 5                        Bur oak / Paper birch
#> 6                        Bur oak / Water birch

# A matrix read from a DELTA data set, with its character table. Body
# length is used because the three ranges do not overlap; the comments are
# text and are left out.
beetles <- readDELTA(system.file("extdata", "tdwg", "beetles-delta", package = "dimoose"))
keyFromMatrix(beetles$matrix, characters = beetles$characters)$leads[c("Character", "Taxon")]
#> Characters of the matrix:
#>   not used, text: comments
#>                                  Character               Taxon
#> 1                   antennal club: present                    
#> 2                    antennal club: absent      Carabus fictus
#> 3   number of lamellae in antennal club: 3 Aphodius exemplaris
#> 4 number of lamellae in antennal club: 4-6 Lucanus imaginarius
```
