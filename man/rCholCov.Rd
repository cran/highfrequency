% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/realizedMeasures.R
\name{rCholCov}
\alias{rCholCov}
\title{CholCov estimator}
\usage{
rCholCov(
  pData,
  IVest = "rMRCov",
  COVest = "rMRCov",
  criterion = "squared duration",
  ...
)
}
\arguments{
\item{pData}{a list. Each list-item i contains an \code{xts} object with the intraday price data (in levels)
of stock \eqn{i} for day \eqn{t}. The order of the data does not matter as it will be sorted according to the criterion specified in the \code{criterion} argument}

\item{IVest}{integrated variance estimator, default is \code{"rMRCov"}. For a list of implemented estimators, use \code{listCholCovEstimators()}.}

\item{COVest}{covariance estimator, default is \code{"rMRCov"}. For a list of implemented estimators, use \code{listCholCovEstimators()}.}

\item{criterion}{criterion to use for sorting the data according to liquidity. 
Possible values are \code{"squared duration"}, \code{"duration"}, \code{"count"}, defaults to \code{"squared duration"}.}

\item{...}{additional arguments to pass to \code{IVest} and \code{COVest}. See details.}
}
\value{
a list containing the covariance matrix \code{"CholCov"}, and the Cholesky decomposition \code{"L"} and \code{"G"} such that \eqn{\code{L} \times \code{G} \times \code{L}' = \code{CholCov}}.
}
\description{
Positive semi-definite covariance estimation using the CholCov algorithm.
The algorithm estimates the integrated covariance matrix by sequentially adding series and using `refreshTime` to synchronize the observations.
This is done in order of liquidity, which means that the algorithm uses more data points than most other estimation techniques.
}
\details{
Additional arguments for \code{IVest} and \code{COVest} should be passed in the ... argument.
For the \code{rMRCov} estimator, which is the default, the \code{theta} and \code{delta} parameters can be set. These default to 1 and 0.1 respectively.

The CholCov estimation algorithm is useful for estimating covariances of \eqn{d} series that are sampled asynchronously and with different liquidities.
The CholCov estimation algorithm is as follows:

\itemize{
    \item First sort the series in terms of decreasing liquidity according to a liquidity criterion, such that series \eqn{1} is the most liquid, and series \eqn{d} the least.
    \item Step 1:
    
    Apply refresh-time on \eqn{{a} = \{1\}} to obtain the grid \eqn{\tau^{a}}. 
    
    Estimate \eqn{\hat{g}_{11}} using an IV estimator on  \eqn{f_{\tau^{a}_j}^{(1)}= \hat{u}_{\tau^{a}_j}^{(1)}}.
    
    \item Step 2:
    
    Apply refresh-time on \eqn{{b} = \{1,2\}} to obtain the grid \eqn{\tau^{b}}. 
    
    Estimate \eqn{\hat{h}^{b}_{21}} as the realized beta between \eqn{f_{\tau^{b}_j}^{(1)}} and \eqn{\hat{u}_{\tau^{b}_j}^{(2)}}. Set \eqn{\hat{h}_{21}=\hat{h}^{b}_{21}}.
    
    Estimate \eqn{\hat{g}_{22}} using an IV estimator on  \eqn{f_{\tau^{b}_j}^{(2)}= \hat{u}_{\tau^{b}_j}^{(2)}-\hat{h}_{21}f_{\tau^{b}_j}^{(1)}}. 
    
    \item  Step 3:
    
    Apply refresh-time on \eqn{{c} = \{1,3\}} to obtain the grid \eqn{\tau^{c}}. 
    
    Estimate \eqn{\hat{h}^{c}_{31}} as the realized beta between \eqn{f_{\tau^{c}_j}^{(1)}} and \eqn{\hat{u}_{\tau^{c}_j}^{(3)}}. Set \eqn{\hat{h}_{31}= \hat{h}^{c}_{31}}.
    
    Apply refresh-time on \eqn{{d} = \{1,2,3\}} to obtain the grid \eqn{\tau^{d}}.
    
    Re-estimate \eqn{\hat{h}_{21}^{d}} at the new grid, such that the projections \eqn{f_{\tau^{d}_j}^{(1)}} and \eqn{f_{\tau^{d}_j}^{(2)}} are orthogonal.
    
    Estimate \eqn{\hat{h}^{d}_{32}} as the realized beta between \eqn{f_{\tau^{d}_j}^{(2)}} and \eqn{\hat{u}_{\tau^{d}_j}^{(3)}}. Set \eqn{\hat{h}_{32} = \hat{h}^{d}_{32}}. 
    
    Estimate \eqn{\hat{g}_{33}} using an IV estimator on \eqn{f_{\tau^{d}_j}^{(3)}= \hat{u}_{\tau^{d}_j}^{(3)}-\hat{h}_{32}f_{\tau^{d}_j}^{(2)} -\hat{h}_{31}f_{\tau^{d}_j}^{(1)}}. 
    
    \item Step 4 to d:
    
    Continue in the same fashion by sampling over \eqn{{1,...,k,l}} to estimate \eqn{h_{lk}} using the smallest possible set. 
    
    Re-estimate the \eqn{h_{nm}} with \eqn{m<n\leq k} at every new grid to obtain orthogonal projections. 
    
    Estimate the \eqn{g_{kk}} as the IV of projections based on the final estimates, \eqn{\hat{h}}.
}
}
\references{
Boudt, K., Laurent, S., Lunde, A., Quaedvlieg, R., and Sauri, O. (2017). Positive semidefinite integrated covariance estimation, factorizations and asynchronicity. \emph{Journal of Econometrics}, 196, 347-367.
}
\seealso{
\code{\link{ICov}} for a list of implemented estimators of the integrated covariance.
}
\author{
Emil Sjoerup
}
