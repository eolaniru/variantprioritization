#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { VCF_EXTRACTCALLERMETA } from './main.nf'

workflow {
    // Test with Mutect2 VCF
    def mutect2_meta = [id: 'mutect2_test']
    def mutect2_vcf = file('tests/test_data/mutect2_test.vcf')
    
    VCF_EXTRACTCALLERMETA(
        [mutect2_meta, mutect2_vcf]
    )
    
    VCF_EXTRACTCALLERMETA.out.tsv.view()
}