#' Plotting CellPhoneDB results as a heatmap

#' @param pvals Dataframe corresponding to `pvalues.txt` or `relevant_interactions.txt` from CellPhoneDB.
#' @param degs_analysis Whether `CellPhoneDB` was run in `deg_analysis` mode
#' @param log1p_transform Whether to log1p transform the output.
#' @param show_rownames whether to show row names.
#' @param show_colnames whether to show column names.
#' @param scale scaling mode for pheatmap.
#' @param cluster_cols whether to cluster columns.
#' @param cluster_rows whether to cluster rows.
#' @param border_color border color.
#' @param fontsize_row row font size.
#' @param fontsize_col column font size.
#' @param family font family.
#' @param main plot title.
#' @param treeheight_col height of column dendrogram.
#' @param treeheight_row height of row dendrogram.
#' @param low_col low colour for heatmap.
#' @param mid_col middle colour for heatmap.
#' @param high_col high colour for heatmap.
#' @param alpha pvalue threshold to trim.
#' @param return_tables whether or not to return the results as a table rather than the heatmap
#' @param symmetrical whether or not to return as symmetrical matrix
#' @param ... passed to pheatmap::pheatmap.
#' @return pheatmap object of cellphone db output
#' @examples
#' \donttest{
#' data(kidneyimmune)
#' data(cpdb_output2)
#' plot_cpdb_heatmap(pvals2)
#' }
#' @import pheatmap
#' @export

plot_cpdb_heatmap <- function(
    pvals, degs_analysis = FALSE, log1p_transform = FALSE,
    show_rownames = TRUE, show_colnames = TRUE, scale = "none", cluster_cols = TRUE,
    cluster_rows = TRUE, border_color = "white", fontsize_row = 11, fontsize_col = 11,
    family = "Arial", main = "", treeheight_col = 0, treeheight_row = 0, low_col = "dodgerblue4",
    mid_col = "peachpuff", high_col = "deeppink4", alpha = 0.05, return_tables = FALSE,
    symmetrical = TRUE, ...) {
  requireNamespace("reshape2")
  requireNamespace("grDevices")

  all_intr <- pvals
  col_start <- ifelse(colnames(all_intr)[DEFAULT_CLASS_COL] == "classification", DEFAULT_V5_COL_START, DEFAULT_COL_START)
  intr_pairs <- all_intr$interacting_pair
  all_intr <- t(all_intr[, -c(1:col_start - 1)])
  colnames(all_intr) <- intr_pairs
  all_count <- reshape2::melt(all_intr)
  if (!degs_analysis) {
    all_count$significant <- all_count$value < alpha
  } else {
    all_count$significant <- all_count$value == 1
  }
  count1x <- all_count %>%
    group_by(Var1) %>%
    summarise(COUNT = sum(significant)) %>%
    as.data.frame()
  tmp <- lapply(count1x[, 1], function(x) strsplit(as.character(x), "\\|"))
  tmp <- lapply(tmp, function(x) x[[1]])
  tmp <- as.data.frame(do.call(rbind, tmp))
  colnames(tmp) <- c("SOURCE", "TARGET")
  count1x <- as.data.frame(cbind(count1x, tmp))
  all_count <- count1x[, c("SOURCE", "TARGET", "COUNT")]

  if (any(all_count$COUNT) > 0) {
    count_mat <- reshape2::acast(SOURCE ~ TARGET, data = all_count, value.var = "COUNT")
    count_mat[is.na(count_mat)] <- 0
    col.heatmap <- (grDevices::colorRampPalette(c(low_col, mid_col, high_col)))(1000)
    if (symmetrical) {
      dcm <- diag(count_mat)
      count_mat <- count_mat + t(count_mat)
      diag(count_mat) <- dcm
    }

    if (log1p_transform == TRUE) {
      count_mat <- log1p(count_mat)
    }

    p <- pheatmap(count_mat,
      show_rownames = show_rownames, show_colnames = show_colnames,
      scale = scale, cluster_cols = cluster_cols, border_color = border_color,
      cluster_rows = cluster_rows, fontsize_row = fontsize_row, fontsize_col = fontsize_col,
      main = main, treeheight_row = treeheight_row, family = family, color = col.heatmap,
      treeheight_col = treeheight_col, ...
    )
    if (return_tables) {
      if (symmetrical) {
        all_sum <- rowSums(count_mat)
        all_sum <- data.frame(all_sum)
        return(list(count_network = count_mat, interaction_count = all_sum))
      } else {
        count_mat <- t(count_mat) # so that the table output is the same layout as the plot
        row_sum <- rowSums(count_mat)
        col_sum <- colSums(count_mat)
        all_sum <- data.frame(row_sum, col_sum)
        return(list(count_network = count_mat, interaction_count = all_sum))
      }
    } else {
      return(p)
    }
  } else {
    stop("There are no significant results using p-value of: ", alpha, call. = FALSE)
  }
}
