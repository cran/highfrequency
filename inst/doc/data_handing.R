## ---- include = FALSE----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ------------------------------------------------------------------------
library(highfrequency)
head(sample_tdataraw_microseconds)

## ----eval = TRUE---------------------------------------------------------
summary(sample_tdataraw_microseconds[, c("DT", "SIZE", "PRICE")])

## ----eval = TRUE---------------------------------------------------------
tdata_cleaned <- tradesCleanup(tdataraw = sample_tdataraw_microseconds, exchange = "N")

## ----eval = TRUE---------------------------------------------------------
tdata_cleaned$report

summary(tdata_cleaned$tdata[, c("DT", "SIZE", "PRICE")])

## ----eval = TRUE---------------------------------------------------------
qdata_cleaned <- quotesCleanup(qdataraw = sample_qdataraw_microseconds, exchange = "N")

## ----eval = TRUE---------------------------------------------------------
qdata_cleaned$report

summary(qdata_cleaned$qdata[, c("DT", "OFR", "OFRSIZ", "BID", "BIDSIZ", "MIDQUOTE")])

## ----eval = TRUE---------------------------------------------------------
tqdata_cleaned <- tradesCleanupUsingQuotes(tdata = tdata_cleaned$tdata[as.Date(DT) == "2018-01-02"], 
                                           qdata = qdata_cleaned$qdata[as.Date(DT) == "2018-01-02"])
tqdata_cleaned

