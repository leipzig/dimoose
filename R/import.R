#' Import a dichotomous key from fishbase
#' see https://www.fishbase.se/keys/allkeys.php for a list of keys
#' @param keycode representing some taxa on fishbase
#' @param fishbaseURL fishbase url (swedish one seems best?)
#' @return a moose object
#' @export
#' @importFrom dplyr slice mutate select filter
#' @importFrom httr POST
#' @importFrom tidyr separate
#' @importFrom stringr str_replace_all
#' @importFrom rotl tnrs_match_names
importFishbase <- function(keycode,fishbaseUrl="https://www.fishbase.se/",separateTerms=TRUE) {
  #get desc
  #body > table.basic > tbody > tr:nth-child(1) > th
  httr::GET(paste0(fishbaseUrl,"keys/description.php?keycode=",keycode)) %>%
    httr::content() %>%
    html_nodes("table") %>%
    first() %>%
    html_table(header=FALSE) %>%
    first() %>% first() %>% first() ->
    desc

  #get the key
  # fishbase requires a POST
    # <form action="questions.php" method="post" name="form2">
    #   <input type="hidden" name="keycode" value="1">
    #     <input type="submit" value="Open Key">
    #       </form>
  httr::POST(paste0(fishbaseUrl,"keys/questions.php"), body = list('keycode' = keycode), encode = "form") %>%
    httr::content() %>%
    html_nodes("table") %>%
    html_table() %>%
    first() ->
    keytable

  #fishbase keytables
  names(keytable)<-keytable[3,]
  keytable %>% slice(4:n()) %>% tidyr::separate(col = "Couplet",into=c("Statement","Choice"),sep=" ") %>%
    dplyr::rename(Taxon=Link) %>%
    dplyr::mutate(Taxon=stringr::str_replace_all(Taxon,' Key','')) %>%
    dplyr::mutate(Taxon=stringr::str_replace_all(Taxon,'^ ','')) %>%
    dplyr::mutate(Taxon=stringr::str_replace_all(Taxon,' $','')) %>%
    dplyr::mutate(Taxon=stringr::str_replace_all(Taxon,',',''))  ->
    cleankeytable

  #internal func to descend tree form leaf node to root
  #returns table of all applicable statements and choices for that Taxon
  #can be row-separated if there are multiple traits
  #recursiveDescendingTree('Carcharhinidae',23,'b')

  recursiveDescendingTree<-function(Taxon,stmt,choice){
    cleankeytable %>%
      dplyr::filter(Statement==stmt,Choice==choice) %>%
      dplyr::select(Statement,Choice,Character) %>%
      dplyr::mutate('Taxon'=Taxon) -> trait
    if(separateTerms==TRUE){
      trait %>% tidyr::separate_rows(Character, sep = ";", convert = FALSE) -> trait
    }
    #you've reached the head node
    if(all(!(cleankeytable$Next==stmt))){
      trait$pSt<-''
      trait$pCh<-''
      return(trait)
    }
    cleankeytable %>% dplyr::filter(Next==stmt) %>% dplyr::select(Statement,Choice) -> parent
    trait$pSt<-parent$Statement
    trait$pCh<-parent$Choice
    return(rbind(recursiveDescendingTree(Taxon,parent$Statement,parent$Choice),trait))
  }

  cleankeytable %>% dplyr::filter(Next=='-') %>% dplyr::select(Taxon,Statement,Choice) %>%
    dplyr::mutate(Resolved=rotl::tnrs_match_names(Taxon)) -> leafs
  res<-purrr::pmap_dfr(list(as.list(leafs$Taxon),as.list(leafs$Statement),as.list(leafs$Choice)),recursiveDescendingTree)
  moose$new(res,desc)
}




