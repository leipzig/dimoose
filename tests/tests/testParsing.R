file("tests/fishbaseDescription.html",open="rb") %>%
  read_html() %>%
  rvest::html_nodes("table") %>%
  dplyr::first() %>%
  rvest::html_table(header=FALSE) %>%
  dplyr::first() %>% dplyr::first() %>% dplyr::first() ->
  desc

testthat::expect_equal(desc,"Key to the families of sharks in the Western Central Pacific.")


file("tests/fishbaseDetail.html", open="rb") %>%
  read_html() %>%
  html_nodes("table") %>%
  html_table() %>%
  first() ->
  keytable
