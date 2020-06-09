
#' Manage, manipulate, and mine dichotomous keys
#'
#' A simple socket-based interface to Python. Provides a basic
#' Python server script and R6 class for interacting with a
#' Python process.

#' @name moose-package
#' @aliases moose
#' @docType package
NULL

#' A moose object see https://www.fishbase.se/keys/allkeys.php for a list of keys
#' @param df a dataframe
#' @param desc a description
#' @return a moose object
#' @method initialize initialize
#' @method print print
#' @import R6
#' @export
moose <- R6Class("moose",
                       lock_object = FALSE,
                       lock_class = TRUE,
                       portable = TRUE,
                       class = TRUE,
                       cloneable = TRUE,
                       private = list(
                         .desc = NA,
                         .df = NULL,
                         .meta = NULL,
                         .taxa = NULL
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
                         },
                         meta = function(value) {
                           if (missing(value)) {
                             private$.meta
                           } else {
                             stopifnot(is.data.frame(value), nrow(value) > 0)
                             private$.meta <- value
                             self
                           }
                         },
                         taxa = function(value) {
                           if (missing(value)) {
                             private$.taxa
                           } else {
                             stopifnot(is.data.frame(value), nrow(value) > 0)
                             private$.taxa <- value
                             self
                           }
                         }
                       ),
                       public = list(
                         initialize = function(df, desc = NA, meta = NA, taxa = NA) {
                           private$.df <- df
                           private$.desc <- desc
                           private$.meta <- meta
                           private$.taxa <- taxa
                         },
                         print = function(){
                           print(private$.desc)
                           print(private$.meta)
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


#' A raw HTML object with the potential to be a moose
#' @param df a dataframe
#' @param desc a description
#' @return a rawhtml object
#' @method initialize initialize
#' @method print print
#' @import R6
#' @export
rawhtml <- R6Class("rawhtml",
                        lock_object = FALSE,
                        lock_class = TRUE,
                        portable = TRUE,
                        class = TRUE,
                        cloneable = TRUE,
                        private = list(
                          .desc = NA,
                          .df = NULL,
                          .meta = NULL
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
                          print = function(){
                            print(private$.desc)
                            print(private$.df)
                            print(private$.meta)
                          },
                          initialize = function(keycode,fishbaseUrl="https://www.fishbase.se/",separateTerms=TRUE) {
                            #get desc
                            #body > table.basic > tbody > tr:nth-child(1) > th
                            httr::GET(paste0(fishbaseUrl,"keys/description.php?keycode=",keycode)) %>%
                              httr::content() %>%
                              html_nodes("table") %>%
                              first() %>%
                              html_table(header=FALSE) %>%
                              first() %>% first() %>% first() ->
                              private$.desc

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
                              private$.df
                          }
                        )
)
