w4msalience <- function(
  data_matrix   # a matrix of intensities; features as rows, and samples as columns
, sample_class  # a vector of sample class-levels; length(sample_class) == ncol(data_matrix)
, failure_action = stop
) {
  library(stats)
  # begin sanity checks
  if ( !is.vector(sample_class) || !( is.character(sample_class) || is.factor(sample_class) ) ) {
    failure_action("w4msalience:  Expected sample_class to be a vector of characters of factor-levels")
    return (NULL)
  }
  if ( !is.matrix(data_matrix) && !is.data.frame(data_matrix) ) {
    failure_action("w4msalience:  Expected data_matrix to be a matrix (or data.frame) of numeric")
    return (NULL)
  }
  # transpose data_matrix so that columns are the features
  t_data_matrix <- t(data_matrix)
  if ( !is.matrix(t_data_matrix) || !is.numeric(t_data_matrix) ) {
    failure_action("w4msalience:  Expected data_matrix to be a matrix (or data.frame) of numeric")
    return (NULL)
  }

  feature_names <- colnames(t_data_matrix)

  n_features <- ncol(t_data_matrix)
  n_samples  <- nrow(t_data_matrix)
  if ( length(sample_class) != n_samples ) {
    strF(data_matrix)
    strF(sample_class)
    failure_action(
      sprintf(
        "w4msalience:  The data_matrix has %d samples but sample_class has %d"
      , n_samples
      , length(sample_class)
      )
    )
    return (NULL)
  }
  # end sanity checks

  # "For each feature, 'select sample_class, median(intensity) from feature group by sample_class'."
  # The first column(s) of the result of aggregate has the classifier value(s) specified in the 'by' list.
  medianOfFeatureBySampleClassLevel <- aggregate(
      x = as.data.frame(t_data_matrix)
    , by = list(sample_class)
    , FUN = "median"
    )

  # "For each feature, 'select sample_class, rcv(intensity) from feature group by sample_class'."
  #   cv is less robust; deviation from normality degrades performance
  #     cv(x) == sd(x) / mean(x)
  #   rcv is a "robust" coefficient of variation, expressed as a proportion
  #     rcv(x) == mad(x) / median(x)
  madOfFeatureBySampleClassLevel <- aggregate(
      x = as.data.frame(t_data_matrix)
    , by = list(sample_class)
    , FUN = "mad"
  )

  # Note that `apply(X=array(1:10), MARGIN = 1, FUN = function(x) return(c(x,x^2)))`
  #   produces a matrix with two rows and ten columns

  my_list <- apply(
    X = array(1:n_features)
  , MARGIN = 1
  , FUN = function(x) {
      my_df <- data.frame(
        median = medianOfFeatureBySampleClassLevel[ , 1 + x]
      , mad = madOfFeatureBySampleClassLevel[ , 1 + x]
      )
      my_df$salient_level <- medianOfFeatureBySampleClassLevel[ , 1]
      my_df <- my_df[ order(my_df$median, decreasing = TRUE), ]
      my_dist_df <- my_df[  1:2, ]
      # "robust coefficient of variation", i.e.,
      #    mad(feature-intensity for class-level max_level) / median(feature-intensity for class-level max_level)
      rcv_result <- my_dist_df$mad[1] / my_dist_df$median[1]
      dist_result <-
        ( my_dist_df$median[1] - my_dist_df$median[2] ) /
        sqrt( my_dist_df$mad[1] * my_dist_df$mad[2] )
      if (is.infinite(dist_result) || is.nan(dist_result))
        dist_result <- 0
      mean_median <- mean(my_df$median)
      salience_result <- if (mean_median > 0) my_df$median[1] / mean_median else 0
      return (
        data.frame(
          dist_result     = dist_result
        , max_median      = my_df$median[1]
        , mean_median     = mean_median
        , salience_result = salience_result
        , salient_level   = my_df$salient_level[1]
        , rcv_result      = rcv_result
        )
      )
    }
  )
  results_matrix  <- sapply(X = 1:n_features, FUN = function(i) my_list[[i]])
  results_df <- as.data.frame(t(results_matrix))

  relative_salient_distance <- unlist(results_df$dist_result)
  salience <- unlist(results_df$salience_result)
  salient_level <- unlist(results_df$salient_level)
  max_median <- unlist(results_df$max_median)
  mean_median <- unlist(results_df$mean_median)
  rcv_result <- unlist(results_df$rcv_result)

  salience_df <-
    data.frame(
      # the feature name
      feature                   = feature_names
      # the name (or factor-level) of the class-level with the highest median intensity for the feature
    , max_level                 = salient_level
      # the median intensity for the feature and the level max_level
    , max_median                = max_median
      # the distance between the maximum intensities for the feature at the two highest levels
    , relative_salient_distance = relative_salient_distance
      # the coefficient of variation (expressed as a proportion) for the intensity for the feature and the level max_level
    , salience_rcv              = rcv_result
      # the mean of the medians of intensity for all class-levels for the feature
    , mean_median               = mean_median
      # raw salience is the ratio of the most-prominent level to the mean of all levels for the feature
    , salience                  = salience
      # don't coerce strings to factors (this is a parameter for the data.frame constructor, not a column of the data.frame)
    , stringsAsFactors = FALSE
    )

  return (salience_df)
}

