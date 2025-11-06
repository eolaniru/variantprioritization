# VCF Extract Caller Meta Module

## Description

This module extracts variant caller metadata from VCF file headers. It parses VCF header information to identify:

- **Caller**: The variant calling software used (e.g., Mutect2, DeepVariant, Strelka, DRAGEN, FreeBayes, bcftools)
- **Version**: The version of the variant caller
- **Reference**: The reference genome used (preserved as it appears in the VCF header)
- **Command**: The command line used to generate the VCF (when available)
- **Source**: The raw source line from the VCF header

## Supported Variant Callers

The module has been tested and optimized for:

- **GATK/Mutect2**: Detects from `##GATKCommandLine` header lines
- **DRAGEN**: Detects from `##DRAGENCommandLine` header lines (including TSO500)
- **DeepVariant**: Detects from `##source=DeepVariant` header lines
- **Strelka**: Detects from `##source=strelka` header lines
- **FreeBayes**: Detects from `##source=freeBayes` header lines
- **bcftools**: Detects from `##bcftools_version` and `##bcftools_command` header lines

## Reference Genome Handling

The module preserves the exact reference genome names as they appear in the VCF headers, without standardization. This ensures that the original information from the variant caller is maintained.

Examples:
- `file:///opt/gatk/resources/Homo_sapiens_assembly38.fasta` → `file:///opt/gatk/resources/Homo_sapiens_assembly38.fasta`
- `/data/reference/hg38.fa` → `/data/reference/hg38.fa`
- `GRCh38` → `GRCh38`
- `hg19` → `hg19`

## Usage

### Basic Usage

```nextflow
include { VCF_EXTRACTCALLERMETA } from './modules/nf-core/vcf/extractcallermeta/main'

workflow {
    vcf_ch = Channel.fromPath("*.vcf*").map { file ->
        def meta = [id: file.baseName]
        [meta, file]
    }
    
    VCF_EXTRACTCALLERMETA(vcf_ch)
}
```

### Input

- `tuple val(meta), path(vcf)`: A tuple containing sample metadata and VCF file path
  - `meta`: A Groovy Map containing sample information (e.g., `[id: 'sample1']`)
  - `vcf`: Path to VCF file (`.vcf` or `.vcf.gz`)

### Output

- `tuple val(meta), path("*.caller_meta.tsv")`: TSV file containing extracted metadata
- `path("versions.yml")`: File containing software versions

### Output Format

The output TSV file contains the following fields:

```
key     value
caller  Mutect2
version 4.2.6.1
reference       GRCh38
command gatk --java-options -Xmx4g Mutect2 --reference hg38.fa --input tumor.bam
source  Mutect2
```

## Testing

The module includes comprehensive nf-test suites:

```bash
# Run all tests
nf-test test tests/main.nf.test

# Run specific test
nf-test test tests/main.nf.test --tag "mutect2 - vcf"
```

Test data includes realistic VCF files from major variant callers:
- Mutect2 (both .vcf and .vcf.gz)
- DeepVariant  
- DRAGEN
- Strelka
- FreeBayes
- bcftools

## Dependencies

- **bcftools** (optional): For handling compressed VCF files. If not available, the module falls back to `zcat`.
- **gawk/awk**: For parsing VCF headers

## Implementation Notes

- Handles both compressed (.vcf.gz) and uncompressed (.vcf) files
- Uses AWK for efficient header parsing
- Follows nf-core module conventions
- Includes comprehensive error handling
- Supports stub runs for testing

## Example Output for Different Callers

### Mutect2
```
caller  Mutect2
version 4.2.6.1
reference       file:///opt/gatk/resources/Homo_sapiens_assembly38.fasta
```

### DRAGEN
```
caller  DRAGEN
version 07.021.624.3.10.9
reference       file:///staging/reference/hg38_alt_aware_nohla/reference.fa
```

### DeepVariant
```
caller  DeepVariant
version v1.5.0
reference       file:///opt/deepvariant/reference/GRCh38_no_alt_analysis_set.fasta
```

### Strelka
```
caller  Strelka
version v2.9.10
reference       file:///data/reference/hg38.fa
```

This module is designed to be a reusable nf-core module that can be easily integrated into variant calling pipelines to track and document the tools used for variant calling.