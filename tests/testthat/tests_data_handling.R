library(xts)
library(testthat)
library(data.table)

data.table::setDTthreads(2)

# autoSelectExchangeTrades ------------------------------------------------
test_that("autoSelectExchangeTrades", {
  skip_on_cran()
  expect_equal(
    unique(autoSelectExchangeTrades(sampleTDataRaw, printExchange = FALSE)$EX),
    "D"
  )
  
  expect_equal(
    unique(autoSelectExchangeQuotes(sampleQDataRaw, printExchange = FALSE)$EX),
    "N"
  )

})



# quotesCleanup -----------------------------------------------------------
test_that("quotesCleanup", {
  skip_on_cran()
  expect_equal(
    quotesCleanup(qDataRaw = sampleQDataRaw, exchanges = "N")$report["removedFromSelectingExchange"],
    c(removedFromSelectingExchange = 36109)
  )
})


# aggregatePrice ----------------------------------------------------------
test_that("aggregatePrice", {
  skip_on_cran()
  expect_equal(
    formatC(sum(head(aggregatePrice(sampleTData, alignBy = "secs", alignPeriod = 30))$PRICE), digits = 10),
    "     950.79"
  )
})


# selectExchange and data cleaning functions ------------------------------

test_that("selectExchange and data cleaning functions", {
  skip_on_cran()
  expect_equal(
    unique(selectExchange(sampleQDataRaw, c("N", "P"))$EX),
    c("P", "N")
  )
  
  expect_equal(
    dim(rmOutliersQuotes(selectExchange(sampleQDataRaw, "N"))),
    dim(rmOutliersQuotes(selectExchange(sampleQDataRaw, "N"), type = "standard"))
  )
  
  expect_equal(
    dim(rmTradeOutliersUsingQuotes(selectExchange(sampleTDataRaw, "P"), selectExchange(sampleQDataRaw, "N"), lagQuotes = 2)),
    c(5502, 12)
  )
  
  expect_equal(
    dim(rmLargeSpread(selectExchange(sampleQDataRaw, "N"))),
    c(94422, 7)
  )
  
  expect_equal(
    dim(mergeQuotesSameTimestamp(selectExchange(sampleQDataRaw, "N"), selection = "max.volume")),
    c(46566, 7)
  )
  
  expect_equal(
    dim(mergeQuotesSameTimestamp(selectExchange(sampleQDataRaw, "N"), selection = "weighted.average")),
    c(46566, 7)
  )
  
  expect_equal(
    dim(noZeroQuotes(selectExchange(sampleQDataRaw, "N"))),
    c(94422, 7)
  )
  
  
  expect_equal(
  dim(tradesCleanupUsingQuotes(tData = sampleTDataRaw, qData = sampleQData, lagQuotes = 2)),
  c(72035, 13)
  )
  
  expect_equal(
  dim(tradesCleanup(tDataRaw = sampleTDataRaw, exchanges = "N", report = FALSE)),
  c(7168, 8)
  )
})


# tradesCleanup -----------------------------------------------------------
test_that("tradesCleanup gives same data as the shipped data", {
  skip_on_cran()
  cleaned <-
    tradesCleanupUsingQuotes(
      tData = tradesCleanup(tDataRaw = sampleTDataRaw, exchanges = "N", report = FALSE),
      qData = quotesCleanup(qDataRaw = sampleQDataRaw, exchanges = "N", type = "standard", report = FALSE),
      lagQuotes = 0
    )[, c("DT", "EX", "SYMBOL", "PRICE", "SIZE")]
  
  setkey(cleaned, SYMBOL, DT)
  expect_equal(cleaned, sampleTData)
  
  
})

## tradesCleanup on-disk functionality -------------------------------------
test_that("tradesCleanup on-disk functionality", {
  skip_on_cran()
  if(Sys.getenv("USER") != "emil"){
    skip("Skipped to not mess with other people's files")
  }
  library(data.table)
  DT <- SYMBOL <- NULL
  trades2 <- sampleTDataRaw
  quotes2 <- sampleQDataRaw
  trades2[, DT := as.POSIXct(DT, tz = "UTC")]
  quotes2[, DT := as.POSIXct(DT, tz = "UTC")]
  
  rawDataSource <- paste0(LETTERS[sample(1:26, size = 10)], collapse = "")
  tradeDataSource <- paste0(LETTERS[sample(1:26, size = 10)], collapse = "")
  quoteDataSource <- paste0(LETTERS[sample(1:26, size = 10)], collapse = "")
  dataDestination <- paste0(LETTERS[sample(1:26, size = 10)], collapse = "")
  dir.create(rawDataSource)
  saveRDS(quotes2, paste0(rawDataSource, "/quotes2.rds"))
  saveRDS(trades2, paste0(rawDataSource, "/trades2.rds"))
  
  
  tradesCleanup(dataSource = rawDataSource, dataDestination = tradeDataSource, exchanges = "N", saveAsXTS = FALSE, tz = "UTC")
  quotesCleanup(dataSource = rawDataSource, dataDestination = quoteDataSource, exchanges = "N", saveAsXTS = FALSE, type = "standard", tz = "UTC")
  tradesCleanupUsingQuotes(tradeDataSource = tradeDataSource, quoteDataSource = quoteDataSource, dataDestination = dataDestination,
                           lagQuotes = 0)
  
  onDiskDay1 <- readRDS(paste0(dataDestination, "/", "2018-01-02tradescleanedbyquotes.rds"))
  onDiskDay2 <- readRDS(paste0(dataDestination, "/", "2018-01-03tradescleanedbyquotes.rds"))
  

  unlink(rawDataSource, recursive = TRUE, force = TRUE)
  unlink(tradeDataSource, recursive = TRUE, force = TRUE)
  unlink(quoteDataSource, recursive = TRUE, force = TRUE)
  unlink(dataDestination, recursive = TRUE, force = TRUE)
  
  sampleTDataDay1 <-
    tradesCleanupUsingQuotes(
      tData = tradesCleanup(tDataRaw = sampleTDataRaw[as.Date(DT) == "2018-01-02"], exchanges = "N", report = FALSE),
      qData = quotesCleanup(qDataRaw = sampleQDataRaw[as.Date(DT) == "2018-01-02"], exchanges = "N", type = "standard", report = FALSE),
      lagQuotes = 0
    )[, c("DT", "EX", "SYMBOL", "PRICE", "SIZE")]
  
  
  sampleTDataDay2 <-
    tradesCleanupUsingQuotes(
      tData = tradesCleanup(tDataRaw = sampleTDataRaw[as.Date(DT) == "2018-01-03"], exchanges = "N", report = FALSE),
      qData = quotesCleanup(qDataRaw = sampleQDataRaw[as.Date(DT) == "2018-01-03"], exchanges = "N", type = "standard", report = FALSE),
      lagQuotes = 0
    )[, c("DT", "EX","SYMBOL", "PRICE", "SIZE")]
  
  
  
  onDiskDay1 <- onDiskDay1[as.Date(DT, tz = "EST") == "2018-01-02",c("DT", "EX","SYMBOL", "PRICE", "SIZE")][, DT := DT - 18000]
  onDiskDay2 <- onDiskDay2[as.Date(DT, tz = "EST") == "2018-01-03",c("DT", "EX","SYMBOL", "PRICE", "SIZE")][, DT := DT - 18000]
  setkey(onDiskDay1, SYMBOL, DT)
  setkey(onDiskDay2, SYMBOL, DT)
  expect_equal(onDiskDay1[,-"DT"], sampleTDataDay1[,-"DT"])
  expect_equal(onDiskDay2[,-"DT"], sampleTDataDay2[,-"DT"])
  ## Test that they are equal to the shipped data
  cleaned <-  rbind(sampleTDataDay1, sampleTDataDay2)
  setkey(cleaned, SYMBOL, DT)
  expect_equal(sampleTData, cleaned)
  
})



# test_that("sampleTData matches cleaned sampleTDataRaw", {
#   
#   cleaned <- tradesCleanup(tDataRaw = sampleTDataRaw, exchanges = "N", report = FALSE)  
#   
#   
#   cleaned <- tradesCleanupUsingQuotes(tData = tradesCleanup(tDataRaw = sampleTDataRaw, exchanges = "N", report = FALSE),
#                                       qData = quotesCleanup(qDataRaw = sampleQDataRaw, exchanges = "N", type = "advanced", report = FALSE))
#   
#   
#   cleaned <- cleaned$PRICE
#   old <- sampleTData$PRICE
#   storage.mode(cleaned) <- storage.mode(old) <- "numeric"
#   plot(cleaned, lwd = 1)
#   plot(na.locf(cbind(cleaned, old)), col = 2:1)
#   lines(old, col = "red", lwd = 1)
# })


# aggregateTS xts vs data.table for previoustick --------------------------
test_that("aggregateTS xts vs data.table for previoustick", {
  skip_on_cran()
  res_DT <- aggregateTS(sampleTData[, list(DT, PRICE)])
  expect_true(all.equal(as.xts(res_DT) , c(aggregateTS(as.xts(sampleTData[as.Date(DT) == "2018-01-02", list(DT, PRICE)])),
                                         aggregateTS(as.xts(sampleTData[as.Date(DT) == "2018-01-03", list(DT, PRICE)]))))
  )
})


# aggregateTS edge cases --------------------------------------------------
test_that("aggregateTS edge cases", {
  skip_on_cran()
  # Test edge cases of aggregateTS
  expect_equal(index(aggregateTS(xts(1:23400, as.POSIXct(seq(34200, 57600, length.out = 23400), origin = '1970-01-01')))),
                     index(aggregateTS(xts(1:23400, as.POSIXct(seq(34200, 57599, length.out = 23400), origin = '1970-01-01'))))
  )
  
  expect_true(
    max(index(aggregateTS(xts(1:23400, as.POSIXct(seq(34200, 57600, length.out = 23400), origin = '1970-01-01', alignBy = "minutes", alignPeriod = 1)))))<
    max(index(aggregateTS(xts(1:23400, as.POSIXct(seq(34200, 57601, length.out = 23400), origin = '1970-01-01', alignBy = "minutes", alignPeriod = 1)))))
    # The last one will have an extra minute in this case!
  )

})


# aggregateTS tick returns behave correctly -------------------------------
test_that("aggregateTS tick returns behave correctly",{
  skip_on_cran()
  
  ## Test using every second tick as well as two prime numbers since it's cheap and the primes should give the best coverage.
  DT <- aggregateTS(sampleTData[, list(DT, PRICE)], alignBy = "ticks", alignPeriod = 2)
  XTS <- aggregateTS(as.xts(sampleTData[, list(DT, PRICE)]), alignBy = "ticks", alignPeriod = 2)
  expect_equal(as.numeric(DT$PRICE), as.numeric(XTS))
  expect_true(all.equal(NROW(DT), NROW(XTS)))
  
  DT <- aggregateTS(sampleTData[, list(DT, PRICE)], alignBy = "ticks", alignPeriod = 3)
  XTS <- aggregateTS(as.xts(sampleTData[, list(DT, PRICE)]), alignBy = "ticks", alignPeriod = 3)
  expect_equal(as.numeric(DT$PRICE), as.numeric(XTS))
  expect_true(all.equal(NROW(DT), NROW(XTS)))

  DT <- aggregateTS(sampleTData[, list(DT, PRICE)], alignBy = "ticks", alignPeriod = 11)
  XTS <- aggregateTS(as.xts(sampleTData[, list(DT, PRICE)]), alignBy = "ticks", alignPeriod = 11)
  expect_equal(as.numeric(DT$PRICE), as.numeric(XTS))
  expect_true(all.equal(NROW(DT), NROW(XTS)))
  
  
})



# aggregatePrice time zones -----------------------------------------------
test_that("aggregatePrice time zones", {
  skip_on_cran()
  
  dat <- data.table(DT = as.POSIXct(c(34150, 34201, 34201, 34500, 34500 + 1e-6, 34799, 34799, 34801, 34803, 35099), origin = "1970-01-01", tz = "EST"), PRICE = 0:9)
  
  output <- aggregatePrice(dat, alignBy = "minutes", alignPeriod = 5, marketOpen = "04:30:00", marketClose = "11:00:00", fill = FALSE)
  target <- data.table(DT = as.POSIXct(c(34200, 34500, 34800, 35100), origin = "1970-01-01", tz = "EST"), PRICE = c(1,3,6,9))
  expect_equal(output, target)
  
  dat <- as.xts(dat)
  
  output <- aggregatePrice(dat, alignBy = "minutes", alignPeriod = 5, marketOpen = "04:30:00", marketClose = "11:00:00", fill = FALSE, tz = "EST")
  target <- xts(c(1,3,6,9), as.POSIXct(c(34200, 34500, 34800, 35100), origin = "1970-01-01", tz = "EST")) 
  colnames(target) <- "PRICE"
  expect_equal(output, target)
  
  dat <- data.table(DT = as.POSIXct(c(34150, 34201, 34201, 34500, 34500 + 1e-6, 34799, 34799, 34801, 34803, 35099) + 86400 * c(rep(1,10), rep(200,10)),
                                    origin =  as.POSIXct("1970-01-01", tz = "EST"), tz = "EST"), PRICE = rep(0:9, 2))
  
  output <- aggregatePrice(dat, alignBy = "minutes", alignPeriod = 5, marketOpen = "09:30:00", marketClose = "16:00:00", fill = FALSE)
  target <- data.table(DT = as.POSIXct(c(34200, 34500, 34800, 35100) + 86400 * c(rep(1,4), rep(200,4)), origin = as.POSIXct("1970-01-01", tz = "EST"), tz = "EST"), PRICE = rep(c(1,3,6,9), 2))
  expect_equal(output, target)
  
  
  
})


# aggregatePrice edge cases -----------------------------------------------
test_that("aggregatePrice edge cases", {
  dat <- data.table(DT = as.POSIXct(c(34150, 34201, 34201, 34500, 34500 + 1e-9, 34799, 34799, 34801, 34803, 35099), origin = "1970-01-01", tz = "UTC"), PRICE = 0:9)
  output <- aggregatePrice(dat, alignBy = "minutes", alignPeriod = 5, marketOpen = "09:30:00", marketClose = "16:00:00", fill = FALSE)
  target <- data.table(DT = as.POSIXct(c(34200, 34500, 34800, 35100), origin = "1970-01-01", tz = "UTC"), PRICE = c(1,3,6,9))
  expect_equal(output, target)
})

# aggregatePrice filling different number of symbols over multiple --------
test_that("aggregatePrice filling different number of symbols over multiple days", {
  foo <- rbind(sampleMultiTradeData, sampleMultiTradeData[SYMBOL != "ETF", list(DT = DT + 86400, SYMBOL, PRICE, SIZE)])
  res <- aggregatePrice(foo, fill = TRUE, alignBy = "seconds")
  expect_equal(nrow(res), 5 * 23401)
  expect_equal(res[SYMBOL == "AAA" & as.Date(DT) == "2014-09-17"]$PRICE,
               res[SYMBOL == "AAA" & as.Date(DT) == "2014-09-18"]$PRICE)
  
  
})



# aggregatePrice milliseconds vs seconds ----------------------------------
test_that("aggregatePrice milliseconds vs seconds", {
  
  skip_on_cran()
  
  dat <- data.table(DT = as.POSIXct(c(34150 ,34201, 34500, 34500 + 1e-9, 34799, 34801, 34803, 35099), origin = "1970-01-01", tz = "GMT"), PRICE = 0:7)
  expect_equal(aggregatePrice(dat, alignBy = "milliseconds", alignPeriod = 5000, marketOpen = "09:30:00", marketClose = "16:00:00", fill = TRUE),
               aggregatePrice(dat, alignBy = "secs", alignPeriod = 5, marketOpen = "09:30:00", marketClose = "16:00:00", fill = TRUE))
  
})


# aggregatePrice filling correctly ----------------------------------------
test_that("aggregatePrice filling correctly", {
  
  skip_on_cran()
  
  dat <- data.table(DT = as.POSIXct(c(34150 ,34201, 34800, 45500, 45799, 50801, 50803, 57599.01, 57601), origin = "1970-01-01", tz = "GMT"), PRICE = 0:8)
  output <- aggregatePrice(dat, alignBy = "milliseconds", alignPeriod = 1000, marketOpen = "09:30:00", marketClose = "16:00:00", fill = TRUE)
  expect_equal(sum(output$PRICE == 0), 0) # This should be removed since it happens before the market opens
  expect_equal(sum(output$PRICE == 1), 60 * 10) # 1 is the prevaling price for 10 minutes (It is also the opening price!!!!!)
  expect_equal(sum(output$PRICE == 2), 2 * 60 * 60 + 58 * 60 + 20) # 2 is the prevailing price for 2 hours, 58 minutes and 20 seconds 
  expect_equal(sum(output$PRICE == 3), 4 * 60 + 59) #3 is the prevailiing price for 4 min 59 sec
  expect_equal(sum(output$PRICE == 4), 1 * 60 * 60 + 23 * 60 + 22) # 4 is the prevailiing price for 1 hour, 23 minutes and 22 seconds
  expect_equal(sum(output$PRICE == 5), 2) # 5 is the prevailing price for 2 sec
  expect_equal(sum(output$PRICE == 6), 1 * 60 * 60 + 53 * 60 + 17) # 6 is the prevailing price for 1 hour, 53 mins and 17 sec
  expect_equal(sum(output$PRICE == 7), 1) # 7 only happens once
  expect_equal(sum(output$PRICE == 8), 0) # 8 should be removed since it happens 1 sec after market closes.
  expect_equal(nrow(output), 23401)
})


# aggregateQuotes edge cases ----------------------------------------------
test_that("aggregateQuotes edge cases", {
  skip_on_cran()
  dat <- data.table(DT = as.POSIXct(c(34150 ,34201, 34500, 34500 + 1e-9, 34799, 34801, 34803, 35099), origin = "1970-01-01", tz = "GMT"), 
                    SYMBOL = "XXX", BID = as.numeric(0:7), BIDSIZ = as.numeric(1), OFR = as.numeric(1:8), OFRSIZ = as.numeric(2))
  output <- aggregateQuotes(dat, alignBy = "minutes", alignPeriod = 5, marketOpen = "09:30:00", marketClose = "16:00:00")
  
  target <- data.table(DT = as.POSIXct(c(34200, 34500, 34800, 35100), origin = "1970-01-01", tz = "GMT"),
                       SYMBOL = "XXX", BID = c(1,2,4,7), BIDSIZ = c(1,1,2,3), OFR = c(1,2,4,7) + 1, OFRSIZ = c(1,1,2,3) * 2)
  
  expect_equivalent(output, target)
  
  expect_true(all.equal(output$BIDSIZ * 2 , output$OFRSIZ))
})



# aggregateQuotes milliseconds vs seconds ---------------------------------
test_that("aggregateQuotes milliseconds vs seconds", {
  skip_on_cran()
  dat <- data.table(DT = as.POSIXct(c(34150 ,34201, 34500, 34500 + 1e-12, 34799, 34801, 34803, 35099), origin = "1970-01-01", tz = "GMT"), 
                    SYMBOL = "XXX", BID = as.numeric(0:7), BIDSIZ = as.numeric(1), OFR = as.numeric(1:8), OFRSIZ = as.numeric(2))
  expect_equal(aggregateQuotes(dat, alignBy = "milliseconds", alignPeriod = 5000, marketOpen = "09:30:00", marketClose = "16:00:00"),
               aggregateQuotes(dat, alignBy = "secs", alignPeriod = 5, marketOpen = "09:30:00", marketClose = "16:00:00"))
  
})




# business time aggregation -----------------------------------------------
test_that("business time aggregation",{
  skip_on_cran()
  skip_if_not(capabilities('long.double'), 'Skip tests when long double is not available')
  pData <- sampleTData
  agged1 <- suppressWarnings(businessTimeAggregation(pData, measure = "intensity", obs = 390, bandwidth = 0.075))
  expect_equal(nrow(agged1$pData), 779) # We return the correct number of observations
  
  
  expect_warning(businessTimeAggregation(pData, measure = "volume", obs = 390), "smaller")
  agged2 <- suppressWarnings(businessTimeAggregation(pData, measure = "volume", obs = 390))
  expect_equal(nrow(agged2$pData), 756)
  
  agged3 <- suppressWarnings(businessTimeAggregation(pData, measure = "vol", obs = 39, method = "PARM", RM = "rv", lookBackPeriod = 5))
  expect_equal(nrow(agged3$pData), 76)
  
  # pData <- sampleTData[,c("PRICE", "SIZE")]
  # storage.mode(pData) <- "numeric"
  # agged4 <- businessTimeAggregation(pData, measure = "intensity", obs = 390, bandwidth = 0.075)
  # expect_equal(nrow(agged4$pData), 390) # We return the correct number of observations
  # 
  # 
  # agged5 <- suppressWarnings(businessTimeAggregation(pData, measure = "volume", obs = 78))
  # expect_equal(nrow(agged5$pData), 78)
  # 
  # agged6 <- suppressWarnings(businessTimeAggregation(pData, measure = "vol", obs = 39, method = "PARM", RM = "rv", lookBackPeriod = 5))
  # expect_equal(nrow(agged6$pData), 39)
  
})

# refreshTime -------------------------------------------------------------
test_that("refreshTime", {
  skip_on_cran()
  # Unit test for the refreshTime algorithm based on Kris' example in http://past.rinfinance.com/agenda/2015/workshop/KrisBoudt.pdf
  #suppose irregular timepoints: 
  start <- as.POSIXct("2010-01-01 09:30:00", tz = "GMT") 
  ta <- start + c(1, 2, 4, 5, 9, 14)
  tb <- start + c(1, 3, 6, 7, 8, 9, 10, 11, 15)
  tc <- start + c(1, 2, 3, 5, 7, 8, 10, 13)
  a <- as.xts(1:length(ta), order.by = ta)
  b <- as.xts(1:length(tb), order.by = tb)
  c <- as.xts(1:length(tc), order.by = tc)
  #Calculate the synchronized timeseries: 
  expected <- xts(matrix(c(1,1,1, 2,2,3, 4,3,4, 5,6,6, 6,8,8), ncol = 3, byrow = TRUE), order.by = start + c(1,3,6,9,14))
  colnames(expected) <- c("a", "b", "c")
  expect_equal(refreshTime(list("a" = a, "b" = b, "c" = c)), expected)
  
  squaredDurationCriterion <- function(x) sum(as.numeric(diff(index(x)))^2)
  durationCriterion <- function(x) sum(as.numeric(diff(index(x))))
  sqDur <- sort(sapply(list("a" = a, "b" = b, "c" = c), squaredDurationCriterion), index.return = TRUE)$ix
  dur <- sort(sapply(list("a" = a, "b" = b, "c" = c), durationCriterion), index.return = TRUE)$ix
  
  expect_equal(refreshTime(list("b" = b, "a" = a, "c" = c), sort = TRUE, criterion = "squared duration"), expected[, sqDur])
  expect_equal(refreshTime(list("b" = b, "a" = a, "c" = c), sort = TRUE, criterion = "duration"), expected[, dur])
  
  
  aDT <- data.table(index(a), a)
  colnames(aDT) <- c("DT", "PRICE")
  bDT <- data.table(index(b), b)
  colnames(bDT) <- c("DT", "PRICE")
  cDT <- data.table(index(c), c)
  colnames(cDT) <- c("DT", "PRICE")
  
  RT <- refreshTime(list("a" = aDT, "b" = bDT, "c" = cDT))
  
  expected <- data.table(DT = start + c(1,3,6,9,14), 
                         matrix(c(1,1,1, 2,2,3, 4,3,4, 5,6,6, 6,8,8), ncol = 3, byrow = TRUE, dimnames = list(NULL, c("a", "b", "c"))))
  
  expect_equal(RT, expected)
  
  
  ## Make sure we take copies in the refreshTime() function when we make changes to colnames by reference.
  ## If the copies are disabled in the code these tests fail.
  expect_equal(colnames(aDT), c("DT", "PRICE"))
  expect_equal(colnames(bDT), c("DT", "PRICE"))
  expect_equal(colnames(cDT), c("DT", "PRICE"))
  
  expect_equal(refreshTime(list("a" = aDT, "b" = bDT, "c" = cDT), sort = TRUE, criterion = "squared duration"), 
               expected[, names(expected)[c(1, sqDur + 1)], with = FALSE])
  expect_equal(refreshTime(list("a" = aDT, "b" = bDT, "c" = cDT), sort = TRUE, criterion = "duration"),
               expected[, names(expected)[c(1, dur + 1)], with = FALSE])
  
  
  
})


library(data.table)


# spreadPrices ------------------------------------------------------------
test_that("spreadPrices",{
  skip_on_cran()
  set.seed(1)
  PRICE <- DT <- .N <- NULL
  data1 <- copy(sampleTData)[,  `:=`(PRICE = PRICE * runif(.N, min = 0.99, max = 1.01),
                                                 DT = DT + runif(.N, 0.01, 0.02))]
  data2 <- copy(sampleTData)[, SYMBOL := 'XYZ']
  
  dat1 <- rbind(data1, data2)
  setkey(dat1, "DT")
  dat <- spreadPrices(dat1)
  
  res <- rCov(dat, alignBy = 'minutes', alignPeriod = 5, makeReturns = TRUE, cor = TRUE)
  target <- list("2018-01-02" = matrix(c(1, 0.1936498028,
                                         0.1936498028, 1), ncol = 2),
                 "2018-01-03" = matrix(c(1, 0.1590385524,
                                         0.1590385524, 1), ncol = 2)
                 )
  expect_equal(res, target)
})


# gatherPrices and spreadPrices back and forth ----------------------------
test_that("gatherPrices and spreadPrices back and forth", {
  skip_on_cran()
  set.seed(1)
  PRICE <- DT <- .N <- NULL
  data1 <- copy(sampleTData)[,  `:=`(PRICE = PRICE * runif(.N, min = 0.99, max = 1.01),
                                     DT = DT + runif(.N, 0.01, 0.02))]
  data2 <- copy(sampleTData)[, SYMBOL := 'XYZ']
  
  dat1 <- rbind(data1, data2)[, list(DT, SYMBOL, PRICE)]
  setkeyv(dat1, c("DT", "SYMBOL"))
  dat <- spreadPrices(dat1)
  expect_equal(dat1, gatherPrices(dat))
  expect_equal(spreadPrices(gatherPrices(dat)), dat)
  
})

# aggregateTrades, aggregatePrice, and aggregateQuotes multisymbol --------
test_that("aggregateTrades, aggregatePrice, and aggregateQuotes multisymbol multiday",{
  skip_on_cran()
  datTrades <- merge.data.table(sampleTData, copy(sampleTData)[, SYMBOL := "ABC"][], by = c(colnames(sampleTData)), all = TRUE)
  datQuotes <- merge.data.table(sampleQData, copy(sampleQData)[, SYMBOL := "ABC"][], by = colnames(sampleQData), all = TRUE)
  
  aggTrades <- aggregateTrades(datTrades)
  expect_true(all(split(aggTrades, by = "SYMBOL")[[2]] == aggregateTrades(sampleTData)))
  aggQuotes <- aggregateQuotes(datQuotes)
  expect_true(all(split(aggQuotes, by = "SYMBOL")[[2]] == aggregateQuotes(sampleQData), na.rm = TRUE)) # remove NA because we return all the columns
  
  aggQuotes2 <- aggregatePrice(datQuotes)
  all(split(aggQuotes2, by = "SYMBOL")[[2]] == aggregatePrice(sampleQData), na.rm = TRUE)
  
})


# Backwards-forwards matching algorithm produces correct result -----------
test_that("Backwards-forwards matching algorithm produces correct result", {
  skip_on_cran()
  bfmMatched <- tradesCleanupUsingQuotes(tData = tradesCleanup(tDataRaw = sampleTDataRaw, report = FALSE, exchanges = 'D'),
                                  qData = quotesCleanup(qDataRaw = sampleQDataRaw, type = 'standard', report = FALSE, exchanges = 'N'), 
                                  BFM = TRUE, lagQuotes = 0)
  
  expect_equal(dim(bfmMatched), c(19888, 14))
})



# seqInclEnds -------------------------------------------------------------
test_that("seqInclEnds gives expected result", {
  skip_on_cran()
  target <- c(1,5,9,10)
  expect_equal(target, seqInclEnds(1, 10, 4))
  
  target <- c(1, 4, 7, 10)
  expect_equal(target, seqInclEnds(1, 10, 3))
  
  
  
})
