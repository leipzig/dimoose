# Raw FishBase key tables

An R6 object holding a FishBase key's description and its couplet table
as downloaded, before conversion to a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## Active bindings

- `desc`:

  Key title (read-only).

- `df`:

  The key's couplet table: one row per lead, with columns `Statement`,
  `Choice`, `Character`, `Next`, `Prev` and `Taxon`.

## Methods

### Public methods

- [`rawhtml$print()`](#method-rawhtml-print)

- [`rawhtml$new()`](#method-rawhtml-initialize)

- [`rawhtml$clone()`](#method-rawhtml-clone)

------------------------------------------------------------------------

### `rawhtml$print()`

Print the description, table and metadata.

#### Usage

    rawhtml$print(...)

#### Arguments

- `...`:

  Unused.

------------------------------------------------------------------------

### `rawhtml$new()`

Download a FishBase key.

#### Usage

    rawhtml$new(
      keycode,
      fishbaseUrl = "https://www.fishbase.se/",
      separateTerms = TRUE
    )

#### Arguments

- `keycode`:

  FishBase key code.

- `fishbaseUrl`:

  Base URL of the FishBase mirror.

- `separateTerms`:

  Ignored; kept for backward compatibility.

------------------------------------------------------------------------

### `rawhtml$clone()`

The objects of this class are cloneable with this method.

#### Usage

    rawhtml$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
