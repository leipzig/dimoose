#' Export an interactive dichotomous tree
#' see https://www.fishbase.se/keys/allkeys.php for a list of keys
#' @param moose a dicottomoose object
#' @param displayLinks display HTML anchor links for navigation
#' @param order order of statements, 'original' if imported from an existing tree, 'parsimony' for maximum parsimony
#' @export
#' @importFrom dplyr slice mutate select filter
#' @importFrom httr POST
#' @importFrom tidyr separate
#' @importFrom stringr str_replace_all
exportWizard <- function(moose,displayLinks=TRUE,order='parsimony') {
}


toDataTree<-function(moose,includeStatementNodes=FALSE,includeLoneLeafNodes=FALSE){
  res %>%
    select(Statement,Choice,Character,pSt,pCh) %>%
    mutate(name=paste0(Statement,Choice)) %>%
    mutate(parent=paste0(pSt,pCh)) %>% distinct() %>%
    select(name,parent,Character) %>%
    mutate(parent=ifelse(parent=='','1',parent)) -> network
  FromDataFrameNetwork(network)
}

toPhylo<-function(moose){

}

toPolyclave<-function(moose){
}
