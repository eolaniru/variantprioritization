#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { VCF_EXTRACTCALLERMETA } from './main.nf'

workflow {
    // Test with different VCF files
    def vcf_files = [
        [meta: [id: 'mutect2_test'], vcf: 'tests/test_data/mutect2_test.vcf'],
        [meta: [id: 'deepvariant_test'], vcf: 'tests/test_data/deepvariant_test.vcf'],
        [meta: [id: 'strelka_test'], vcf: 'tests/test_data/strelka_test.vcf'],
        [meta: [id: 'freebayes_test'], vcf: 'tests/test_data/freebayes_test.vcf'],
        [meta: [id: 'bcftools_test'], vcf: 'tests/test_data/bcftools_test.vcf'],
        [meta: [id: 'dragen_test'], vcf: 'tests/test_data/dragen_test.vcf'],
        [meta: [id: 'mutect2_test_gz'], vcf: 'tests/test_data/mutect2_test.vcf.gz']
    ]

    input_ch = Channel.fromList(vcf_files).map { item ->
        [item.meta, file(item.vcf)]
    }
    
    VCF_EXTRACTCALLERMETA(input_ch)
    
    VCF_EXTRACTCALLERMETA.out.tsv.view { meta, tsv ->
        "Sample: ${meta.id}"
        tsv.text
        "---"
    }
}