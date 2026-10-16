# Names of a key's sniglets

Lists the sniglets of a key (or of a
[`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
result) with the names they currently go by. This is the table
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
takes: write it to a CSV file, fill in the `name` and `definition`
columns, and read it back.

## Usage

``` r
snigletNames(x)
```

## Arguments

- x:

  A key from
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md),
  or a
  [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  result.

## Value

A data frame with one row per sniglet:

- `sniglet`: the coined word. It identifies the sniglet and never
  changes.

- `name`: the name people see. It is the coined word until you rename
  it.

- `definition`: an optional sentence saying what the sniglet is.

- `used` (keys only): whether the key asks about this sniglet. Only
  these need names.

## See also

[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
