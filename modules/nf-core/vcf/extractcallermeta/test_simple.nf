#!/usr/bin/env nextflow

// Simple test to validate the VCF_EXTRACTCALLERMETA module
// This script tests the module with a single Mutect2 VCF file

nextflow.enable.dsl = 2

include { VCF_EXTRACTCALLERMETA } from './main.nf'

workflow {
    def test_meta = [id: 'test_sample']
    def test_vcf = file('tests/test_data/mutect2_test.vcf')
    
    VCF_EXTRACTCALLERMETA([test_meta, test_vcf])
    
    VCF_EXTRACTCALLERMETA.out.tsv.view { meta, tsv ->
        println "=== Sample: ${meta.id} ==="
        println tsv.text
        println "========================"
    }
}