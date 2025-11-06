#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { VCF_EXTRACTCALLERMETA } from './main.nf'

workflow {
    // Test with bcftools VCF
    def bcftools_meta = [id: 'bcftools_test']
    def bcftools_vcf = file('tests/test_data/bcftools_test.vcf')
    
    VCF_EXTRACTCALLERMETA(
        [bcftools_meta, bcftools_vcf]
    )
    
    VCF_EXTRACTCALLERMETA.out.tsv.view { meta, tsv ->
        println "=== Sample: ${meta.id} ==="
        println tsv.text
        println "========================"
    }
}