# Memory Optimization for Large Tooltip Datasets

## Overview
The tooltip enhancement process has been optimized to handle large datasets without consuming excessive memory.

## Chunked Processing
The `Permission-Tooltip.ps1` script now processes tooltips in configurable chunks instead of loading everything into memory at once.

### Key Features
- **Chunked Processing**: Processes tooltips in batches (default: 300 per chunk)
- **Memory Cleanup**: Performs garbage collection after each chunk
- **Progress Reporting**: Shows detailed progress for each chunk
- **Configurable Chunk Size**: Adjustable via `TooltipChunkSize` in Configuration.psd1

### Configuration
In your `Configuration.psd1` file:

```powershell
# Number of tooltips to process per chunk (helps manage memory)
TooltipChunkSize = 300  # Adjust based on available memory
```

### Memory Usage Guidelines

| Dataset Size | Recommended Chunk Size | Expected Memory Usage |
|--------------|------------------------|----------------------|
| < 1,000 tooltips | 500-1000 | Minimal impact |
| 1,000-5,000 tooltips | 300-500 | Low-moderate |
| 5,000-10,000 tooltips | 200-300 | Moderate |
| > 10,000 tooltips | 100-200 | Conservative |

### Benefits
1. **Memory Efficiency**: Prevents memory exhaustion on large datasets
2. **Stability**: Reduces risk of script crashes due to memory pressure
3. **Progress Visibility**: Clear progress reporting during processing
4. **Flexibility**: Configurable chunk sizes for different environments

### Processing Output
The script provides enhanced feedback including:
- Chunk-by-chunk progress
- Memory usage tracking
- Processing rate calculations
- Intermediate file size reports

### Troubleshooting
If you encounter memory issues:
1. Reduce `TooltipChunkSize` in Configuration.psd1
2. Close other memory-intensive applications
3. Consider processing on a machine with more RAM
4. Monitor chunk processing for optimal size determination

### Example Output
```
🧩 Using chunked processing with chunks of 300 tooltips
📦 Processing 2847 tooltips in 10 chunks of 300 each
🔄 Processing chunk 1/10 (tooltips 1-300)
✅ Chunk 1 completed - 300/2847 tooltips processed (10.5%)
💾 Current HTML size: 1,234 KB
```
