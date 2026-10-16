# A dichotomous key

An R6 object holding a dichotomous key as a table of the leads on every
path from the root to a terminal taxon. Usually created by
[`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md)
or
[`parseFishbase()`](https://leipzig.github.io/dimoose/reference/parseFishbase.md).
See <https://www.fishbase.se/keys/allkeys.php> for FishBase keys.

## Active bindings

- `desc`:

  Key title or description (read-only).

- `df`:

  Data frame with one row per lead (or per term, if terms were
  separated) per terminal taxon, with columns `Statement`, `Choice`,
  `Character`, `Taxon`, and `pSt`/`pCh` for the parent lead.

- `meta`:

  Key/value data frame of metadata (citation, image URLs, ...).

- `taxa`:

  Data frame of terminal taxa and their resolved names.

- `leads`:

  Data frame with one row per lead: `Statement`, `Choice`, `Character`,
  `Next` (next couplet, or `"-"` if terminal) and `Taxon`, plus optional
  `Prev`, `Image`, `ImageLink`, `TaxonUrl`, `Question`, `Feature`,
  `Test` and `Threshold`. Derived from `df` when the object was created
  without one.

- `features`:

  Data frame of features a machine can compute, one per row (see
  [`featureTable()`](https://leipzig.github.io/dimoose/reference/featureTable.md)),
  or `NULL` for keys meant only for people.

## Methods

### Public methods

- [`dimoose$new()`](#method-dimoose-initialize)

- [`dimoose$print()`](#method-dimoose-print)

- [`dimoose$summary()`](#method-dimoose-summary)

- [`dimoose$validate()`](#method-dimoose-validate)

- [`dimoose$toDataTree()`](#method-dimoose-toDataTree)

- [`dimoose$toNewick()`](#method-dimoose-toNewick)

- [`dimoose$clone()`](#method-dimoose-clone)

------------------------------------------------------------------------

### `dimoose$new()`

Create a new dimoose object.

#### Usage

    dimoose$new(df, desc = NA, meta = NA, taxa = NA, leads = NULL, features = NULL)

#### Arguments

- `df`:

  Data frame of leads (see the `df` field).

- `desc`:

  Key title or description.

- `meta`:

  Key/value metadata data frame.

- `taxa`:

  Data frame of terminal taxa.

- `leads`:

  Optional data frame of leads (see the `leads` field).

- `features`:

  Optional data frame of machine-readable features (see
  [`featureTable()`](https://leipzig.github.io/dimoose/reference/featureTable.md)).

------------------------------------------------------------------------

### `dimoose$print()`

Print a short overview of the key.

#### Usage

    dimoose$print(...)

#### Arguments

- `...`:

  Unused.

------------------------------------------------------------------------

### `dimoose$summary()`

Counts describing the key.

#### Usage

    dimoose$summary()

#### Returns

A one-row data frame: `title`, `couplets`, `leads`, `taxa`, `depth`
(longest path in steps) and `problems` (see `validate()`).

------------------------------------------------------------------------

### `dimoose$validate()`

Check the key: leads to missing couplets, terminal leads without a
taxon, couplets with fewer than two leads, couplets that cannot be
reached from the first one, and (for keys with features) leads whose
machine test is missing or inconsistent.

#### Usage

    dimoose$validate()

#### Returns

A character vector of problems, invisibly if there are none.

------------------------------------------------------------------------

### `dimoose$toDataTree()`

Convert the key to a
[data.tree::Node](https://rdrr.io/pkg/data.tree/man/Node.html): couplets
are internal nodes and taxa leaves; each child node carries the `lead`
label and the `character` text of the lead that leads to it. A couplet
reached from several leads is attached under the first.

#### Usage

    dimoose$toDataTree()

------------------------------------------------------------------------

### `dimoose$toNewick()`

Write the key's topology in Newick format, with couplets as internal
node labels and taxa as leaves (labels quoted when needed). A couplet
reached from several leads is placed under the first.

#### Usage

    dimoose$toNewick()

#### Returns

A single string ending in `;`.

------------------------------------------------------------------------

### `dimoose$clone()`

The objects of this class are cloneable with this method.

#### Usage

    dimoose$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
