#' Lead-Lag estimation
#' @description Function that estimates whether one series leads (or lags) another.
#' 
#' Let \eqn{X_{t}} and \eqn{Y_{t}} be two observed price over the time interval \eqn{[0,1]}.
#' 
#' For every integer \eqn{k \in \cal{Z}}, we form the shifted time series
#' 
#' \deqn{
#'    Y_{\left(k+i\right)/n},  \quad i = 1, 2, \dots
#' }
#' \eqn{H=\left(\underline{H},\overline{H}\right]} is an interval for \eqn{\vartheta\in\Theta}, define the shift interval \eqn{H_{\vartheta}=H+\vartheta=\left(\underline{H}+\vartheta,\overline{H}+\vartheta\right]} then let
#' 
#' \deqn{
#'     X\left(H\right)_{t}=\int_{0}^{t}1_{H}\left(s\right)\textrm{d}X_{s}
#' }
#' 
#' Which will be abbreviated:
#' \deqn{
#'     X\left(H\right)=X\left(H\right)_{T+\delta}=\int_{0}^{T+\delta}1_{H}\left(s\right)\textrm{d}X_{s}
#' }
#' 
#' Then the shifted HY contrast function is:
#' \deqn{
#'     \tilde{\vartheta}\rightarrow U^{n}\left(\tilde{\vartheta}\right)= \\
#'     1_{\tilde{\vartheta}\geq0}\sum_{I\in{\cal{I}},J\in{\cal{J}},\overline{I}\leq T}X\left(I\right)Y\left(J\right)1_{\left\{ I\cap J_{-\tilde{\vartheta}}\neq\emptyset\right\}} \\
#'     +1_{\tilde{\vartheta}<0}\sum_{I\in{\cal{I}},J\in{\cal{J}},\overline{J}\leq T}X\left(I\right)Y\left(Y\right)1_{\left\{ J\cap I_{\tilde{\vartheta}}\neq\emptyset\right\} }
#' }
#' This contrast function is then calculated for all the lags passed in the argument \code{lags}
#' 
#' @param price1 \code{xts} or \code{data.table} containing prices in levels, in case of data.table,
#'  use a column DT to denote the date-time in POSIXct format, and a column PRICE to denote the price
#' @param price2 \code{xts} or \code{data.table} containing prices in levels, in case of data.table,
#'  use a column DT to denote the date-time in POSIXct format, and a column PRICE to denote the price
#' @param lags a numeric denoting which lags (in units of \code{resolution}) should be tested as leading or lagging
#' @param resolution the resolution at which the lags is measured. 
#' The default is "seconds", use this argument to gain 1000 times resolution by setting it to either "ms", "milliseconds", or "milli-seconds".
#' @param normalize logical denoting whether the contrasts should be normalized by the product of the L2 norms of both the prices. Default = TRUE. 
#' This does not change the value of the lead-lag-ratio.
#' @param parallelize logical denoting whether to use a parallelized version of the C++ code (parallelized using OPENMP). Default = FALSE
#' @param nCores integer valued numeric denoting how many cores to use for the lead-lag estimation procedure in case parallelize is TRUE. 
#' Default is NA, which does not parallelize the code.
#' 
#' @return A list with class \code{leadLag} which contains \code{contrasts}, \code{lead-lag-ratio}, and \code{lags}, denoting the estimated values for each lag calculated,
#' the lead-lag-ratio, and the tested lags respectively.
#' 
#' @details The lead-lag-ratio (LLR) can be used to see if one asset leads the other. If LLR < 1, then price1 MAY be leading price2 and vice versa if LLR > 1.
#' 
#' @references Hoffmann, M., Rosenbaum, M., and Yoshida, N. (2013). Estimation of the lead-lag parameter from non-synchronous data. \emph{Bernoulli}, 19, 1-37.
#' 
#' @examples 
#' \dontrun{
#' # Toy example to show the usage
#' # Spread prices
#' spread <- spreadPrices(sampleMultiTradeData[SYMBOL %in% c("ETF", "AAA")])
#' # Use lead-lag estimator
#' llEmpirical <- leadLag(spread[!is.na(AAA), list(DT, PRICE = AAA)], 
#'                        spread[!is.na(ETF), list(DT, PRICE = ETF)], seq(-15,15))
#' plot(llEmpirical)
#' }
#' 
#' @export
leadLag <- function(price1 = NULL, price2 = NULL, lags = NULL, resolution = "seconds", normalize = TRUE, parallelize = FALSE, nCores = NA){
  PRICE <- DT <- timestampsX <- timestampsY <- x <- y <- NULL # initialization
  # Make adjustments if we are doing millisecond precision
  timestampsCorrectionFactor <- 1
  if(resolution %in% c("ms", "milliseconds", "milli-seconds")){
    timestampsCorrectionFactor <- 1000
  }
  if(!is.numeric(lags) | (length(lags) < 1)){
    stop(" lags must be a numeric with a length greater than 0")
  }
  if(!all(class(price1) == class(price2))){
    stop("price1 and price2 must be of same class")
  }

  if(parallelize && is.numeric(nCores) && (nCores %% 1) == 0 && nCores < 1){
    parallelize <- FALSE
    warning("nCores is not an integer valued numeric greater than 0. Using non-parallelized code")
  }
  
  ## Test if we have data.table input
  if(is.data.table(price1)){ # We can check one because we check that the classes are the same above
    
    if (!("DT" %in% colnames(price1))) {
      stop("price1 neeeds DT column (date-time ).")
    }
    if (!("PRICE" %in% colnames(price1))) {
      stop("price1 neeeds PRICE column.")
    }
    if (!("DT" %in% colnames(price2))) {
      stop("price2 neeeds DT column (date-time).")
    }
    if (!("PRICE" %in% colnames(price2))) {
      stop("price2 neeeds PRICE column.")
    }
    
    timestampsX <- as.numeric(price1[, DT]) * timestampsCorrectionFactor
    timestampsY <- as.numeric(price2[, DT]) * timestampsCorrectionFactor
    x <- as.numeric(price1[, PRICE])
    y <- as.numeric(price2[, PRICE])
  } else { # Here we have XTS input
    # Make sure we have correct xts inputs
    if(!is.xts(price1) | !is.xts(price2) | isMultiXts(price1)| isMultiXts(price2)){
      stop(paste0("lead-lag estimation requires the input to be contain single day input. The input must be either xts or data.table, not ", 
                  class(price1)))
    } 
    timestampsX <- as.numeric(index(price1)) * timestampsCorrectionFactor
    timestampsY <- as.numeric(index(price2)) * timestampsCorrectionFactor
    
    if(ncol(price1) > 1){
      x <- as.numeric(price1[, "PRICE"])
      y <- as.numeric(price2[, "PRICE"])
    } else {
      x <- as.numeric(price1)
      y <- as.numeric(price2)
    }
  }
  
  if(anyNA(x) || anyNA(y) || anyNA(timestampsX) || anyNA(timestampsY)){
    stop(paste0("lead-lag function does not support NAs in prices or timestamps please take measures to remove these"))
  }
  
  
  # When y is longer than x, it is often faster to swap the variables than run with a longer y than x.
  isSwapped <- FALSE
  if(length(x) < length(y)){
    tmp <- x
    x <- y
    y <- tmp
    tmp <- timestampsX
    timestampsX <- timestampsY
    timestampsY <- tmp
    isSwapped <- TRUE
  }

  # Convert timestamps to denote time after open (denoted by first trade in either asset)
  origin <- min(timestampsY[1], timestampsX[1])
  timestampsX <- timestampsX - origin
  timestampsY <- timestampsY - origin
  
  
  # (1 + -2 * isSwapped) is 1 if isSwapped is FALSE, and -1 if isSwapped is TRUE
  if(parallelize){
    contrasts <- as.numeric(leadLagCppPAR(x, timestampsX, y, timestampsY, lags * (1 + -2 * isSwapped), normalize, nCores))    
  } else {
    contrasts <- as.numeric(leadLagCpp(x, timestampsX, y, timestampsY, lags * (1 + -2 * isSwapped), normalize))
  }
  
  
  # Calculate the likelihood ratio
  posIDX <- which(lags>0)
  negIDX <- which(lags<0)
  if( length(negIDX) != 0 ){
    LLR <- sum(contrasts[posIDX]) / sum(contrasts[negIDX])
  } else {
    LLR <- NA
  }
  
  res <- list("contrasts" = contrasts, "lead-lag-ratio" = LLR, "lags" = lags)
  class(res) <- c("leadLag", "list")
  return(res)
  
}


#' @export 
plot.leadLag <- function(x, ...){
  plot(x$lags, x$contrasts, type = "l", main = "lead-lag estimation", xlab = "lag", ylab = "contrast")
}