CRAN: [![CRAN Version](http://www.r-pkg.org/badges/version/moose)](https://cran.r-project.org/package=moose/) [![CRAN downloads](http://cranlogs.r-pkg.org/badges/moose)](https://cran.r-project.org/package=moose/)

Master: [![Build Status master](https://travis-ci.org/leipzig/moose.svg?branch=master)](https://travis-ci.org/leipzig/moose) [![Windows Build status]( https://ci.appveyor.com/api/projects/status/github/leipzig/moose?branch=master&svg=true)](https://ci.appveyor.com/project/leipzig/moose) [![codecov.io](http://codecov.io/github/leipzig/moose/coverage.svg?branch=master)](http://codecov.io/github/leipzig/moose?branch=master)

Dev: [![Build Status dev](https://travis-ci.org/leipzig/moose.svg?branch=dev)](https://travis-ci.org/leipzig/moose) [![Windows Build status]( https://ci.appveyor.com/api/projects/status/github/leipzig/moose?branch=dev&svg=true)](https://ci.appveyor.com/project/leipzig/moose) [![codecov.io](http://codecov.io/github/leipzig/moose/coverage.svg?branch=dev)](http://codecov.io/github/leipzig/moose?branch=dev)

# moose
An R package to manage dichotomous keys

Dichotomous keys are bifurcating trees that are often used in species identification. More precisely, dichotomous keys are binary categorical decision trees with unique leaves.

Despite their different uses, phylogenetic trees are similar to dichotomous keys:
- the paths are traversed using mutation "decisions" instead of visible phenotypes
- all points on a phylogenetic tree represent an organism that actually existed (instead of a group of possibilities)

Moose supports phylogenetic trees in which the mutations are known, such as Phylotree.

This package provides tools to do the following
- convert from and to popular formats including consensus matrices, ape phylo, data.tree, data frames, JSON, YAML
- merge and prune dichotomous keys
- generate interactive dichotomous keys ("wizards")
- produce training data for machine learning using splits
- metadata slots for provenance and supporting guide images
- perform basic lexical analysis, and specialized data types (single nucleotide variations) of criteria and taxa
- ontological annotation, together with `pepper`(https://github.com/leipzig/pepper) labels at the decision nodes and edges can be mapped to ontologies using join tables
- build mixed effects conditional inference trees (mecits)

# Getting started

To get started, you might want to read the [introduction vignette](https://CRAN.R-project.org/package=moose/vignettes/moose.html). There is also a vignette containing some [examples and applications](https://CRAN.R-project.org/package=moose/vignettes/applications.html).

The manual is [here](https://CRAN.R-project.org/package=moose/moose.pdf)

# Acknowledgments

Moose is built on phylo4, since it has the closest native resemblance to dichotomous trees but also borrows from data.tree and partykit.

Karl Broman's R Package Primer was useful in this process.
