# Skip unless `url` actually answers. DNS alone (skip_if_offline) is not enough
# behind proxies or when the service itself is down.
skip_if_unreachable <- function(url) {
  ok <- tryCatch(
    httr::status_code(httr::HEAD(url, httr::timeout(10))) < 500,
    error = function(e) FALSE
  )
  if (!isTRUE(ok)) skip(paste("cannot reach", url))
}
