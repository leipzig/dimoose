#' A dicottomoose object see https://www.fishbase.se/keys/allkeys.php for a list of keys
#' @param df a dataframe
#' @param desc a description
#' @return a dicottomoose object
#' @method initialize initialize
#' @method print print
#' @import R6
#' @export
dicottomoose <- R6Class("dicttomoose",
                       lock_object = FALSE,
                       lock_class = TRUE,
                       portable = TRUE,
                       class = TRUE,
                       cloneable = TRUE,
                       private = list(
                         .desc = NA,
                         .df = NULL
                       ),
                       active = list(
                         desc = function(value) {
                           if (missing(value)) {
                             private$.desc
                           } else {
                             stop("`$desc` is read only", call. = FALSE)
                           }
                         },
                         df = function(value) {
                           if (missing(value)) {
                             private$.df
                           } else {
                             stopifnot(is.data.frame(value), nrow(value) > 0)
                             private$.df <- value
                             self
                           }
                         }
                       ),
                       public = list(
                         initialize = function(df, desc = NA) {
                           private$.df <- df
                           private$.desc <- desc
                         },
                         print = function(){
                           print(private$.desc)
                           print(private$.df)
                         },
                         toDataTree = function(includeStatementNodes=FALSE,includeLoneLeafNodes=FALSE){
                           private$.df %>%
                             select(Statement,Choice,Character,pSt,pCh) %>%
                             mutate(name=paste0(Statement,Choice)) %>%
                             mutate(parent=paste0(pSt,pCh)) %>% distinct() %>%
                             select(name,parent,Character) %>%
                             mutate(parent=ifelse(parent=='','1',parent)) -> network
                           data.tree::FromDataFrameNetwork(network)
                         },
                         toPolyclave = function(delim=';'){
                           private$.df
                         }
                       )
)
