Fixtures for test-sdd.R, test-delta.R and test-lucid.R

One file is real third-party data:

- `tetractenion.lif3`: the Lucid 4 matrix key to the species of
  *Tetractenion* (6 species, 10 features), unchanged. Source: Berry TR, van
  Noort S (2020) Revision of the endemic Afrotropical genus Tetractenion
  (Hymenoptera, Ichneumonidae) with an identification key to genera of
  Banchinae for the region. ZooKeys 1007: 49-84, Supplementary material 2,
  https://doi.org/10.3897/zookeys.1007.55543.suppl2 (file `oo_492597.lif3`,
  md5 85dd41e103735bf59a087117e1bcfbc4). Licence: CC0 1.0 (public domain
  dedication), as stated on its Zenodo record 4422223.

All other files here were written by hand for these tests. They are not
copies of third-party data, but each one follows the layout of real files:

- `lucid-export.sdd.xml`: the features the TDWG test file
  `SDD-Test-Lucid.sdd11.xml` (github.com/tdwg/sdd, 2006/Schema/1.1) lists as
  supported by Lucid 3: descriptive concepts, a character tree, state
  modifiers kept in a second dataset, status codes, the four Lucid measures.
- `xper2.sdd.xml`: the SDD dialect written by Xper2 (no taxon list, the taxon
  is the label of the coded description, dependency rules in the character
  tree).
- `keys.sdd.xml`: identification keys laid out like the TDWG test file
  `SDD-Test-IdentificationKey.sdd11.xml`: a polytomous lead-style key that
  hands over to a subkey, and a question-and-answer key that is incomplete.
- `delta/`: a DELTA dataset in the classic three files, using the syntax of
  the DELTA standard (Dallwitz & Paine, "Definition of the DELTA format") and
  of the "Grass Genera" sample dataset distributed with the DELTA programs.
  The files have Windows line ends and are in Windows-1252, as DELTA files
  usually are.
- `onefile.dlt`: specifications and items in one file, with no character list.
- `beetles.lif3`: Lucid Interchange Format 3, laid out like keys exported by
  the Lucid 3 Builder (`<lif3_key>` with properties, items, trees,
  descriptions and media).
