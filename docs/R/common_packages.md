# Popular R package

## seurat 

**Seurat** is one of the most popular and comprehensive R packages for the `quality control (QC)`, `analysis`, and `exploration`
of `single-cell RNA sequencing (scRNA-seq)` data. Developed and maintained by the Satija Lab (NYGC), 
it provides an end-to-end toolkit to:

- Load and store single-cell expression matrices
- Perform quality control and filtering
- Normalize data
- Identify highly variable genes
- Scale data and run dimensionality reduction (PCA, UMAP, t-SNE)
- Cluster cells
- Find marker genes
- Visualize results
- Integrate multiple datasets
- Handle multimodal data (e.g., CITE-seq, spatial transcriptomics) and very large datasets (Seurat v5)


A working example: 

```R
# Standard installation from CRAN (installs the latest stable version)
install.packages("Seurat")

# Load the package
library(Seurat)

# Optional: Install SeuratData for easy access to example datasets
install.packages("SeuratData")
library(SeuratData)

## load sample data
pbmc <- LoadData("pbmc3k")
pbmc   # Prints a nice summary of the object

## quality Control
# Calculate mitochondrial percentage (common QC metric)
pbmc[["percent.mt"]] <- PercentageFeatureSet(pbmc, pattern = "^MT-")

# Visualize QC metrics
VlnPlot(pbmc, features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3)
FeatureScatter(pbmc, feature1 = "nCount_RNA", feature2 = "nFeature_RNA")

# filter low quality cells
pbmc <- subset(pbmc, subset = nFeature_RNA > 200 & 
                        nFeature_RNA < 2500 & 
                        percent.mt < 5)
                        
## Normalization + Find Variable Features
# Standard log-normalization
pbmc <- NormalizeData(pbmc)

# Identify highly variable genes (features)
pbmc <- FindVariableFeatures(pbmc, selection.method = "vst", nfeatures = 2000)

# Optional but recommended: Scale data
pbmc <- ScaleData(pbmc, features = rownames(pbmc))

## Dimensionality reduction + clustering
# PCA
pbmc <- RunPCA(pbmc, features = VariableFeatures(pbmc))

# UMAP (non-linear reduction for visualization)
pbmc <- RunUMAP(pbmc, dims = 1:10)

# Find neighbors and clusters
pbmc <- FindNeighbors(pbmc, dims = 1:10)
pbmc <- FindClusters(pbmc, resolution = 0.5)   # resolution controls granularity

## Visualization
# UMAP colored by cluster
DimPlot(pbmc, reduction = "umap", label = TRUE) + NoLegend()

# UMAP colored by a gene (e.g., MS4A1 = CD20, a B-cell marker)
FeaturePlot(pbmc, features = "MS4A1")

# Violin plot of a marker across clusters
VlnPlot(pbmc, features = "MS4A1")

## Find Cluster Markers (differential expression)
# Find markers for cluster 0 vs all others
markers <- FindMarkers(pbmc, ident.1 = 0, min.pct = 0.25)

# Top positive markers
head(markers, n = 10)
```

## Harmony

`Harmony` is a popular and very efficient R package for `batch correction and integration of single-cell RNA-seq (and other single-cell) datasets`.

Developed by the Raychaudhuri lab (originally Korsunsky et al., 2019), it corrects for technical batch effects (e.g., different donors, experiments, technologies, or sequencing platforms) while preserving biological variation (cell types).
Harmony is especially valued because it is:
- Extremely fast and memory-efficient (can handle >1 million cells on a laptop)
- Works directly on low-dimensional embeddings (usually PCA)
- Supports multiple covariates at once (e.g., batch + sex + treatment)
- Integrates very well with Seurat (the most common use case) and SingleCellExperiment

It is not a full analysis pipeline like Seurat. Instead, it is typically used after you have performed normalization, 
variable feature selection, and PCA in Seurat.


A working example:

```R
# From CRAN (recommended)
install.packages("harmony")

# Load the package
library(Seurat)
library(harmony)
library(dplyr)   # optional, for piping

# For the latest development version:
# devtools::install_github("immunogenomics/harmony", build_vignettes = TRUE)

# Example: Suppose you have two 10X datasets (ctrl and stim)
# In practice, use LoadData("pbmcsca") or merge your own objects

# For illustration, we'll pretend we have a combined object with a "dataset" column
# pbmc <- merge(pbmc_ctrl, pbmc_stim)   # or use SeuratData

# Add metadata for batch
pbmc$dataset <- pbmc$orig.ident   # or whatever your batch variable is

# Standard preprocessing on the merged object
pbmc <- NormalizeData(pbmc)
pbmc <- FindVariableFeatures(pbmc, selection.method = "vst", nfeatures = 2000)
pbmc <- ScaleData(pbmc)
pbmc <- RunPCA(pbmc, npcs = 30, verbose = FALSE)

# Integrate using the "dataset" column as the batch variable
pbmc <- RunHarmony(pbmc, 
                   group.by.vars = "dataset",   # can be c("dataset", "tech") for multiple
                   reduction = "pca",           # input reduction
                   assay.use = "RNA",
                   reduction.save = "harmony",  # name of new reduction
                   verbose = TRUE)

# Check that the new reduction was added
Reductions(pbmc)   # should now include "pca" and "harmony"

## Downstream analysis using Harmony embeddings
# UMAP on harmony-corrected embeddings (instead of raw PCA)
pbmc <- RunUMAP(pbmc, reduction = "harmony", dims = 1:20)

# Clustering on harmony embeddings
pbmc <- FindNeighbors(pbmc, reduction = "harmony", dims = 1:20)
pbmc <- FindClusters(pbmc, resolution = 0.8)

# Visualization
DimPlot(pbmc, reduction = "umap", group.by = "dataset") + 
  ggtitle("UMAP after Harmony integration (colored by batch)")

DimPlot(pbmc, reduction = "umap", label = TRUE) + 
  ggtitle("UMAP colored by clusters")

# Compare to before integration (often shows clear batch separation)
# DimPlot(pbmc, reduction = "umap", group.by = "dataset") but with original PCA would show separation

## Find markers
# Markers for cluster 2
markers <- FindMarkers(pbmc, ident.1 = 2, min.pct = 0.25)
head(markers, n = 10)
```


## dplyr

**dplyr** is one of the most popular and powerful R packages for data manipulation and wrangling. It is part of the 
`tidyverse` and provides a consistent, readable "grammar of data manipulation" with simple verb functions that make 
common tasks (filtering rows, selecting columns, creating new variables, grouping, and summarizing) fast and intuitive.


```R
# Install from CRAN (recommended)
install.packages("dplyr")

# Or install the full tidyverse (includes dplyr + ggplot2, tidyr, etc.)
install.packages("tidyverse")

# Load the package
library(dplyr)

# Load example data
data(starwars)   # or starwars <- dplyr::starwars
glimpse(starwars)   # nice summary (like str() but better)

# # Filter for humans with brown eyes
starwars |> 
  filter(species == "Human", eye_color == "brown")

# Filter using OR (newer way with when_any)
starwars |> 
  filter(when_any(hair_color == "none", eye_color == "black"))

# Remove rows with missing height (filter_out is new in recent versions)
starwars |> 
  filter_out(is.na(height))
  
# Select specific columns
starwars |> 
  select(name, height, mass, species)

# Select by patterns (very useful!)
starwars |> 
  select(name, ends_with("color"), contains("birth"))
  
## Create/modify columns 
# Add BMI column
starwars |> 
  mutate(bmi = mass / ((height / 100)^2),
         height_m = height / 100) |> 
  select(name, height_m, mass, bmi)
  
## aggregation
# Average height and mass by species (only species with >5 characters)
starwars |> 
  group_by(species) |> 
  summarise(
    n = n(),                    # count per group
    avg_height = mean(height, na.rm = TRUE),
    avg_mass = mean(mass, na.rm = TRUE)
  ) |> 
  filter(n > 5) |> 
  arrange(desc(avg_height))
  
## combining operations
starwars |> 
  filter(species == "Human") |> 
  mutate(bmi = mass / ((height / 100)^2)) |> 
  select(name, height, mass, bmi, homeworld) |> 
  arrange(desc(bmi)) |> 
  slice(1:5)   # take top 5 rows
```
## readr
`readr` is a core tidyverse package in R designed for fast and friendly reading of rectangular data (flat files) such 
as `CSV, TSV, delimited files`, and fixed-width files.

## forcats

`forcats` is a tidyverse package that makes working with categorical variables (called factors in R) much easier and more intuitive.

## stringr

`stringr` is a core tidyverse package that provides a clean, consistent, and easy-to-use set of functions for string (text) manipulation in R.

## ggplot2


## tibble

`tibble` is a modern, tidyverse-style replacement for base R’s `data.frame`.
It is the central data structure used by dplyr, readr, stringr, forcats, ggplot2, and most tidyverse workflows (including single-cell analysis with Seurat).

Why use tibble instead of `data.frame`?

- Better printing (only shows first 10 rows + first few columns by default)
- No automatic conversion of character vectors to factors
- No automatic dropping of dimensions (no more drop = TRUE surprises)
- Strict subsetting ([ returns a tibble, never a vector)
- Helpful column name checking and warnings
- Faster and more consistent behavior with tidyverse functions

## lubridate

`lubridate` is the tidyverse package that makes working with dates and times in R much easier, more intuitive, and less error-prone.


## tidyr

`tidyr` is the tidyverse package dedicated to tidying messy data — reshaping it into tidy data format, where:

- Each variable is a column
- Each observation is a row
- Each cell contains a single value

It complements dplyr perfectly:
- dplyr: manipulates data (filter, mutate, summarise, etc.)
- tidyr: changes the shape of the data (wide ↔ long, nesting, separating values)

## purrr

`purrr` is the tidyverse package for `functional programming in R`. It provides a consistent, readable set of tools to 
work with functions and vectors/lists, replacing messy for loops and lapply()/sapply() with clean, pipe-friendly code.

