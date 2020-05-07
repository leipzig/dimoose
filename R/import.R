#' Import a dichotomous key from fishbase
#' see https://www.fishbase.se/keys/allkeys.php for a list of keys
#' @param keycode representing some taxa on fishbase
#' @return a dicottomoose object
#' @export
#' @importFrom dplyr slice mutate select filter
#' @importFrom httr POST
#' @importFrom tidyr separate
#' @importFrom stringr str_replace_all
importFishbase <- function(keycode,fishbaseUrl="https://www.fishbase.se/keys/questions.php") {
  body <- list('keycode' = keycode)

  # fishbase requires a POST
    # <form action="questions.php" method="post" name="form2">
    #   <input type="hidden" name="keycode" value="1">
    #     <input type="submit" value="Open Key">
    #       </form>
  r <- httr::POST(fishbaseUrl, body = body, encode = "form")
  content<-httr::content(r)

  #fishbase keytables
  html_nodes(content,"table") %>% html_table() %>% first() -> keytable
  names(keytable)<-keytable[3,]
  keytable %>% slice(4:n()) %>% tidyr::separate(col = "Couplet",into=c("Statement","Choice"),sep=" ") %>%
    dplyr::rename(Species=Link) %>%
    dplyr::mutate(Species=stringr::str_replace_all(Species,' Key','')) %>%
    dplyr::mutate(Species=stringr::str_replace_all(Species,'^ ','')) %>%
    dplyr::mutate(Species=stringr::str_replace_all(Species,' $','')) %>%
    dplyr::mutate(Species=stringr::str_replace_all(Species,',','')) ->
    cleankeytable

  recursiveDescendingTree<-function(species,stmt,choice){
    cleankeytable %>% dplyr::filter(Statement==stmt,Choice==choice) %>% dplyr::select(Statement,Choice,Character) %>% dplyr::mutate('Species'=species) -> trait
    #you've reached the head node
    if(all(!(cleankeytable$Next==stmt))){
      return(trait)
    }
    cleankeytable %>% dplyr::filter(Next==stmt) %>% dplyr::select(Statement,Choice) -> parent
    return(rbind(recursiveDescendingTree(species,parent$Statement,parent$Choice),trait))
  }

  cleankeytable %>% dplyr::filter(Next=='-')
}
