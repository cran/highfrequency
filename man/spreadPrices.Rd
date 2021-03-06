% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dataHandling.R
\name{spreadPrices}
\alias{spreadPrices}
\title{Convert to format for realized measures}
\usage{
spreadPrices(data)
}
\arguments{
\item{data}{An \code{xts} or a \code{data.table} object with at least \code{"DT"}, 
\code{"SYMBOL"}, and \code{"PRICE"} columns. This data should already be cleaned.}
}
\value{
An \code{xts} or a \code{data.table} object with columns \code{"DT"} and 
a column named after each unique entrance in the \code{"SYMBOL"} column of the input. 
These columns contain the price of the associated symbol. We drop all other columns, e.g. \code{SIZE}.
}
\description{
Convenience function to split data from one \code{xts} or \code{data.table} 
with at least \code{"DT"}, \code{"SYMBOL"}, and \code{"PRICE"} columns to a format 
that can be used in the functions for calculation of realized measures. 
This is the opposite of \code{\link{gatherPrices}}.
}
\examples{
\dontrun{
library(data.table)
data1 <- copy(sampleTData)[,  `:=`(PRICE = PRICE * runif(.N, min = 0.99, max = 1.01),
                                               DT = DT + runif(.N, 0.01, 0.02))]
data2 <- copy(sampleTData)[, SYMBOL := 'XYZ']

dat <- rbind(data1, data2)
setkey(dat, "DT")
dat <- spreadPrices(dat)

rCov(dat, alignBy = 'minutes', alignPeriod = 5, makeReturns = TRUE, cor = TRUE) 
}
}
\seealso{
\code{\link{gatherPrices}}
}
\author{
Emil Sjoerup.
}
