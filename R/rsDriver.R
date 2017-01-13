#' Start a selenium server and browser
#'
#' @param port Port to run on
#' @param browser Which browser to start
#' @param version what version of Selenium Server to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("seleniumserver")
#' @param chromever what version of Chrome driver to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("chromedriver"), A value of NULL
#'     excludes adding the chrome browser to Selenium Server.
#' @param geckover what version of Gecko driver to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("geckodriver"), A value of NULL
#'     excludes adding the firefox browser to Selenium Server.
#' @param phantomver what version of PhantomJS to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("phantomjs"), A value of NULL
#'     excludes adding the PhantomJS headless browser to Selenium Server.
#' @param iedrver what version of IEDriverServer to run. Default = "latest"
#'     which runs the most recent version. To see other version currently
#'     sourced run binman::list_versions("iedriverserver"), A value of NULL
#'     excludes adding the internet explorer browser to Selenium Server.
#'     NOTE this functionality is Windows OS only.
#' @param verbose If TRUE, include status messages (if any)
#' @param ... Additional arguments to pass to \code{\link{remoteDriver}}
#'
#' @return A list containing a server and a client. The server is the object
#' returned by \code{\link[wdman]{selenium}} and the client is an object of class
#' \code{\link{remoteDriver}}
#' @details This function is a wrapper around \code{\link[wdman]{selenium}}.
#'     It provides a "shim" for the current issue running firefox on 
#'     Windows. For a more detailed set of functions for running binaries
#'     relating to the Selenium/webdriver project see the 
#'     \code{\link[wdman]{wdman}} package. Both the client and server
#'     are closed using a registered finalizer. 
#' @export
#' @importFrom wdman selenium
#'
#' @examples
#' \dontrun{
#' # start a chrome browser
#' rD <- rsDriver()
#' rD$client$navigate("http://www.google.com/ncr")
#' rD$client$navigate("http://www.bbc.com")
#' rm(rD)
#' gc(rD) # should clean up
#' }

rsDriver <- function(port = 4567L,
                     browser = c("chrome", "firefox", "phantomjs", 
                                 "internet explorer"),
                     version = "latest",
                     chromever = "latest",
                     geckover = "latest",
                     iedrver = NULL,
                     phantomver = "latest", 
                     verbose = TRUE, ...){
  selServ <- wdman::selenium(port = port, verbose = verbose)
  browser <- match.arg(browser)
  remDr <- remoteDriver(browserName = browser, port = port, ...)
  # shim for blocking pipe issue on windows and firefox
  if(identical(binman:::get_os(), "win")){
    res <- tryCatch(
      httr::with_config(
        httr::timeout(3), 
        remDr$open(silent = !verbose)
      ),
      error = function(e){e}
    )
    if(inherits(res, "error")){
      if(!grepl("Timeout was reached", res[["message"]])){
        selServ$stop()
        stop(res[["message"]])
      }else{
        oldSessions <- length(remDr$getSessions())
        chk <- NA_character_
        while(!identical(chk, character())){
          chk <- selServ$error(timeout = 1000)
        }
        count <- 0L
        while(length(sessions <- remDr$getSessions()) <= oldSessions){
          Sys.sleep(1)
          count <- count + 1L
          if(count > 4L){
            selServ$stop()
            stop("Could not start new browser")
          }
        }
        sessions <- remDr$getSessions()
        remDr$sessionInfo <- sessions[[length(sessions)]]
      }
    }
  }else{
    if(identical(browser, "internet explorer")){
      selServ$stop()
      stop("Internet Explorer is only available on Windows.")
    }
    remDr <- remoteDriver(browserName = browser, port = port)
    remDr$open(silent = !verbose)
  }
  csEnv <- new.env()
  csEnv[["server"]] <- selServ
  csEnv[["client"]] <- remDr
  clean <- function(e){
    e[["client"]]$close()
    e[["server"]]$stop()
  }
  reg.finalizer(csEnv, clean)
  class(csEnv) <- c("rsClientServer",class(csEnv))
  return(csEnv)
}