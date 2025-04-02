#' Import a dichotomous key from fishbase
#' see https://www.fishbase.se/keys/allkeys.php for a list of keys
#' @param keycode representing some taxa on fishbase
#' @param fishbaseURL fishbase url (swedish one seems best?)
#' @param usePhyloService GNR for Global Names Resolver, TRNS for Phylotastic Taxonomic Name Resolution Service
#' @return a moose object
#' @export
#' @importFrom dplyr slice mutate select filter first nth n
#' @importFrom httr POST GET content
#' @importFrom tidyr separate
#' @importFrom stringr str_replace_all
#' @importFrom taxize tnrs gna_verifier
#' @importFrom rvest html_nodes html_table html_attr
#' @import magrittr
#' @importFrom base64enc base64encode

# Helper function to download and encode images
downloadAndEncodeImage <- function(img_url, base_url = "https://www.fishbase.se") {
  tryCatch(
    {
      full_url <- if (startsWith(img_url, "http")) img_url else paste0(base_url, sub("^\\.\\.?", "", img_url))
      response <- httr::GET(full_url)
      if (httr::status_code(response) == 200) {
        raw_content <- httr::content(response, as = "raw")
        encoded <- base64enc::base64encode(raw_content)
        return(encoded)
      }
      return(NULL)
    },
    error = function(e) {
      warning(paste("Failed to download image:", img_url))
      return(NULL)
    }
  )
}

importFishbase <- function(keycode, fishbaseUrl = "https://www.fishbase.se/", separateTerms = TRUE, usePhyloService = "GNR") {
  # get desc
  response <- httr::GET(paste0(fishbaseUrl, "keys/description.php?keycode=", keycode))
  content <- httr::content(response)
  tables <- rvest::html_nodes(content, "table")

  # Extract description and metadata
  desc_table <- rvest::html_table(tables[[1]], header = FALSE)
  meta_list <- list()

  # Handle the description table structure
  if (is.data.frame(desc_table)) {
    desc <- desc_table[1, 1]
    meta_list[["citation"]] <- desc_table[2, 1]
    meta_list[["transcription"]] <- desc_table[3, 1]
  } else {
    desc <- desc_table[[1]][1, 1]
    meta_list[["citation"]] <- desc_table[[1]][2, 1]
    meta_list[["transcription"]] <- desc_table[[1]][3, 1]
  }

  # get the key
  key_response <- httr::POST(paste0(fishbaseUrl, "keys/questions.php"),
    body = list("keycode" = keycode),
    encode = "form"
  )
  key_content <- httr::content(key_response)
  key_tables <- rvest::html_nodes(key_content, "table")
  keytable <- rvest::html_table(key_tables[[1]])

  # Get images from the page
  imgs <- rvest::html_nodes(key_content, "img")
  img_srcs <- rvest::html_attr(imgs, "src")
  # Filter for GIF images in Morphpic directory
  gif_srcs <- img_srcs[grepl("Morphpic/.*\\.gif$", img_srcs)]

  # Download and encode images
  for (img_src in unique(gif_srcs)) {
    encoded <- downloadAndEncodeImage(img_src, fishbaseUrl)
    if (!is.null(encoded)) {
      # Extract the image name from the path
      img_name <- sub(".*/(.*)\\.gif$", "\\1", img_src)
      meta_list[[paste0("image_", img_name)]] <- encoded
    }
  }

  # Convert meta_list to data frame
  meta_df <- data.frame(
    key = names(meta_list),
    value = unlist(meta_list),
    stringsAsFactors = FALSE
  )

  # fishbase keytables
  col_names <- as.character(unlist(keytable[3, ]))
  names(keytable) <- col_names
  keytable %>%
    slice(4:n()) %>%
    tidyr::separate(col = "Couplet", into = c("Statement", "Choice"), sep = " ") %>%
    dplyr::rename(Taxon = Link) %>%
    dplyr::mutate(Taxon = stringr::str_replace_all(Taxon, " Key", "")) %>%
    dplyr::mutate(Taxon = stringr::str_replace_all(Taxon, "^ ", "")) %>%
    dplyr::mutate(Taxon = stringr::str_replace_all(Taxon, " $", "")) %>%
    dplyr::mutate(Taxon = stringr::str_replace_all(Taxon, ",", "")) ->
  cleankeytable

  # internal func to descend tree form leaf node to root
  recursiveDescendingTree <- function(Taxon, stmt, choice) {
    cleankeytable %>%
      dplyr::filter(Statement == stmt, Choice == choice) %>%
      dplyr::select(Statement, Choice, Character) %>%
      dplyr::mutate("Taxon" = Taxon) -> trait
    if (separateTerms == TRUE) {
      trait %>% tidyr::separate_rows(Character, sep = ";", convert = FALSE) -> trait
    }
    # you've reached the head node
    if (all(!(cleankeytable$Next == stmt))) {
      trait$pSt <- ""
      trait$pCh <- ""
      return(trait)
    }
    cleankeytable %>%
      dplyr::filter(Next == stmt) %>%
      dplyr::select(Statement, Choice) -> parent
    trait$pSt <- parent$Statement
    trait$pCh <- parent$Choice
    return(rbind(recursiveDescendingTree(Taxon, parent$Statement, parent$Choice), trait))
  }

  # Get leaf nodes and resolve taxa
  cleankeytable %>%
    dplyr::filter(Next == "-") %>%
    dplyr::select(Taxon, Statement, Choice) -> leafs

  # Handle taxonomy resolution
  tryCatch(
    {
      if (usePhyloService == "GNR") {
        # Create a standardized taxonomy data frame
        taxa <- data.frame(
          submitted_name = leafs$Taxon,
          matched_name = leafs$Taxon, # Default to submitted name
          stringsAsFactors = FALSE
        )

        # Try to get verified names
        verified <- taxize::gna_verifier(leafs$Taxon)
        if (!is.null(verified) && nrow(verified) > 0) {
          # Convert verified to data frame if it's a tibble
          verified <- as.data.frame(verified)
          # Map verified names back to taxa data frame
          for (i in seq_along(leafs$Taxon)) {
            match_idx <- which(verified$name_submitted == leafs$Taxon[i])
            if (length(match_idx) > 0) {
              taxa$matched_name[i] <- verified$name_matched[match_idx[1]]
            }
          }
        }
      } else if (usePhyloService == "TNRS") {
        tnrs_result <- taxize::tnrs(leafs$Taxon)
        taxa <- data.frame(
          submitted_name = leafs$Taxon,
          matched_name = tnrs_result$matched_name,
          stringsAsFactors = FALSE
        )
      } else {
        stop("Use GNR or TNRS for usePhyloService")
      }
    },
    error = function(e) {
      # If taxonomy resolution fails, create a basic resolved data frame
      warning("Taxonomy resolution failed. Creating basic resolution table.")
      taxa <- data.frame(
        submitted_name = leafs$Taxon,
        matched_name = leafs$Taxon,
        stringsAsFactors = FALSE
      )
    }
  )

  # Process all leaf nodes
  df <- purrr::pmap_dfr(
    list(
      as.list(leafs$Taxon),
      as.list(leafs$Statement),
      as.list(leafs$Choice)
    ),
    recursiveDescendingTree
  )

  # Ensure df is a data frame with required columns
  if (!is.data.frame(df) || nrow(df) == 0) {
    df <- data.frame(
      Statement = character(),
      Choice = character(),
      Character = character(),
      Taxon = character(),
      pSt = character(),
      pCh = character(),
      stringsAsFactors = FALSE
    )
  }

  moose$new(df, desc, meta_df, taxa)
}

#' Load consensus matrix from I. Noguerola and A.R. Blanch "Identification of Vibrio spp. with a set of dichotomous keys" doi:10.1111/j.1365-2672.2008.03730.x
#' @example data(vibrio)
#' @example importVibrio(vibrio)
importVibrio <- function(consensus) {
  consensus
}

#' Generate a tree from a feature matrix using various machine learning methods
#' @param data A data frame containing the feature matrix
#' @param target_col The name of the target/response column
#' @param method The method to use for tree generation: "rpart", "randomForest", or "gbm"
#' @param params Optional list of parameters specific to the chosen method
#' @return A tree object of the corresponding type (rpart, randomForest, or gbm)
#' @export
#' @importFrom rpart rpart
#' @importFrom randomForest randomForest
#' @importFrom gbm gbm
generateTree <- function(data, target_col, method = "rpart", params = list()) {
  # Validate inputs
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }
  if (!target_col %in% names(data)) {
    stop("target_col must be a column name in data")
  }
  if (!method %in% c("rpart", "randomForest", "gbm")) {
    stop('method must be one of: "rpart", "randomForest", "gbm"')
  }

  # Create formula
  feature_cols <- setdiff(names(data), target_col)
  formula <- as.formula(paste(target_col, "~", paste(feature_cols, collapse = " + ")))

  # Generate tree based on chosen method
  tree <- switch(method,
    "rpart" = {
      # Default rpart parameters
      default_params <- list(
        method = "class",
        control = rpart::rpart.control(minsplit = 20, minbucket = 7, cp = 0.01)
      )
      # Merge user params with defaults
      params <- modifyList(default_params, params)
      # Call rpart with all parameters
      do.call(
        rpart::rpart,
        c(list(formula = formula, data = data), params)
      )
    },
    "randomForest" = {
      # Default randomForest parameters
      default_params <- list(
        ntree = 500,
        mtry = floor(sqrt(length(feature_cols)))
      )
      # Merge user params with defaults
      params <- modifyList(default_params, params)
      # Call randomForest with all parameters
      do.call(
        randomForest::randomForest,
        c(list(formula = formula, data = data), params)
      )
    },
    "gbm" = {
      # Default gbm parameters
      default_params <- list(
        distribution = "bernoulli",
        n.trees = 100,
        interaction.depth = 3,
        shrinkage = 0.1,
        cv.folds = 5
      )
      # Merge user params with defaults
      params <- modifyList(default_params, params)
      # Call gbm with all parameters
      do.call(
        gbm::gbm,
        c(list(formula = formula, data = data), params)
      )
    }
  )

  return(tree)
}
