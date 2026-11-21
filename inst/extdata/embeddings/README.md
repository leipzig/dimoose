# Embeddings of the example photos

Embeddings of dimoose's example photos and texts, so that the examples and the
vision vignette can be followed on a computer with no Python. Read them with
`loadEmbeddings()`:

```r
pics <- loadEmbeddings(system.file("extdata", "embeddings", "pics-clip-vit-b-32.safetensors", package = "dimoose"))
```

| File | What | Arrays | Model |
|---|---|---|---|
| `pics-clip-vit-b-32.safetensors` | the 36 fruit photos in `extdata/pics` | `image` 36 x 512; `patches` 36 x 16 x 512 (4 x 4 tiles) | CLIP ViT-B/32 (OpenAI weights) |
| `new-photos-clip-vit-b-32.safetensors` | the 6 photos in `extdata/new-photos` | `image` 6 x 512; `patches` 6 x 16 x 512 | CLIP ViT-B/32 |
| `texts-clip-vit-b-32.safetensors` | the vignette's 8 vocabulary prompts and `"a photo of <fruit>."` for the 6 fruits | one matrix, 14 x 512, the texts as row names | CLIP ViT-B/32 |
| `montana-bioclip.safetensors` | the 14 photos in `extdata/montana` and `"a photo of <species>."` for the 11 species of `montanaKey()` | `image` 14 x 512; `texts` 11 x 512 | BioCLIP |

Rows are named by photo id (as `imageSet()` gives it) or by the text. All
embeddings have unit length. They are stored as 16-bit floats to keep the
files small: each number is within 0.00025 of the model's 32-bit one, and the
sniglet key of the vignette comes out the same as from freshly made
embeddings. The file format is described in `?saveEmbeddings`; each file
records the model it was made with (`attr(x, "model")`).

They were made with the ONNX Runtime backend at full precision (`"fp32"`),
whose embeddings equal the PyTorch ones (cosine 1.0000 on these photos):

```r
library(dimoose)
out <- "inst/extdata/embeddings"
ext <- function(...) system.file("extdata", ..., package = "dimoose")

clip <- onnxModel("clip-vit-base-patch32")
images <- imageSet(ext("pics"))
saveEmbeddings(embedImages(clip, images), file.path(out, "pics-clip-vit-b-32.safetensors"),
               precision = "float16", model = clip)
new <- list.files(ext("new-photos"), full.names = TRUE)
saveEmbeddings(embedImages(clip, new), file.path(out, "new-photos-clip-vit-b-32.safetensors"),
               precision = "float16", model = clip)
vocab <- data.frame(feature  = c("a smooth skin", "a round shape", "a yellow colour", "green leaves on top"),
                    opposite = c("a rough skin", "a long shape", "a dark colour", "no leaves"))
texts <- c(vocabularyPrompts(vocab, "a photo of a fruit with {x}"), sprintf("a photo of %s.", unique(images$label)))
saveEmbeddings(embedTexts(clip, texts), file.path(out, "texts-clip-vit-b-32.safetensors"),
               precision = "float16", model = clip)

exportOnnxModel("bioclip")            # once; needs PyTorch
bioclip <- onnxModel("bioclip")
key <- montanaKey()
taxa <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
prompts <- sprintf("a photo of %s.", sub("^.*\\(([^()]+)\\)$", "\\1", taxa))
photos <- list.files(ext("montana"), pattern = "\\.jpg$", full.names = TRUE)
saveEmbeddings(list(image = embedImages(bioclip, photos, patches = FALSE)$image, texts = embedTexts(bioclip, prompts)),
               file.path(out, "montana-bioclip.safetensors"), precision = "float16", model = bioclip)
```
