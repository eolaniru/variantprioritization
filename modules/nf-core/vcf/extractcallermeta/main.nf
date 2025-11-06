process VCF_EXTRACTCALLERMETA {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5a/5acacb55c52bec97c61fd34ffa8721fce82ce823005793592e2a80bf71632cd0/data':
        'community.wave.seqera.io/library/bcftools:1.21--4335bec1d7b44d11' }"

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(meta), path("*.caller_meta.tsv"), emit: tsv
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Extract header from VCF file (handles both .vcf and .vcf.gz)
    if [[ ${vcf} == *.gz ]]; then
        if command -v bcftools &> /dev/null; then
            bcftools view -h ${vcf} > header.txt
        else
            zcat ${vcf} | grep '^#' > header.txt
        fi
    else
        grep '^#' ${vcf} > header.txt
    fi

    # Extract caller metadata using AWK
    awk -v OUT="${prefix}.caller_meta.tsv" '
    BEGIN{
        caller=""; version=""; ref=""; cmd=""; src=""; 
        seen_dragen=0; seen_gatk=0;
        print "key\\tvalue" > OUT;
    }

    # Keep raw source if present (many callers)
    /^##source=/ { 
        if (src=="") src=substr(\$0,10) 
    }

    # GATK / Mutect2 detection
    /^##GATKCommandLine=</ {
        seen_gatk=1;
        if (match(\$0, /ID=([^,>]+)/)) {
            if (caller=="") caller=substr(\$0, RSTART+3, RLENGTH-3);
        }
        if (match(\$0, /Version="([^"]+)"/)) {
            if (version=="") version=substr(\$0, RSTART+9, RLENGTH-10);
        }
        if (match(\$0, /CommandLine="([^"]+)/)) {
            if (cmd=="") cmd=substr(\$0, RSTART+13, RLENGTH-13);
        }
    }

    # DRAGEN detection (including TSO500)
    /^##DRAGENCommandLine=</ {
        id=""; ver=""; sw="";
        if (match(\$0, /ID=([^,>]+)/)) {
            id=substr(\$0, RSTART+3, RLENGTH-3);
        }
        if (match(\$0, /Version="([^"]+)"/)) {
            ver=substr(\$0, RSTART+9, RLENGTH-10);
            # Extract SW version from DRAGEN version string
            if (match(ver, /SW: *([0-9][0-9\\.]+)/)) {
                sw=substr(ver, RSTART+3);
                gsub(/^ +/, "", sw);  # Remove leading spaces
                gsub(/, .*/, "", sw); # Remove everything after comma
            }
        }
        if (match(\$0, /CommandLineOptions="([^"]+)"/)) {
            if (cmd=="") cmd=substr(\$0, RSTART+20, RLENGTH-21);
        }
        
        if (id == "dragen") { 
            caller="DRAGEN"; 
            seen_dragen=1; 
        } else if (caller=="" && seen_dragen==0 && id!="") { 
            caller="DRAGEN_" id; 
        }
        if (sw != "") version=sw;
        else if (version=="" && ver!="") version=ver;
    }

    # bcftools detection
    /^##bcftools_version=/ { 
        if (caller=="") caller="bcftools";
        if (version=="") version=substr(\$0,20);
    }
    /^##bcftools_command=/ { 
        if (cmd=="") cmd=substr(\$0,20);
    }

    # DeepVariant detection
    /^##source=/ && caller=="" {
        s=substr(\$0,10);
        if (match(s, /DeepVariant/)) {
            caller="DeepVariant";
            if (match(s, /v[0-9][0-9\\.a-zA-Z+-]*/)) {
                version=substr(s, RSTART, RLENGTH);
            } else if (match(s, /DeepVariant\\/[0-9][0-9\\.a-zA-Z+-]*/)) {
                version=substr(s, RSTART+11);
            }
        }
    }

    # Strelka detection
    /^##source=/ && caller=="" {
        s=substr(\$0,10);
        if (match(s, /strelka/)) {
            caller="Strelka";
            if (match(s, /v[0-9][0-9\\.a-zA-Z+-]*/)) {
                version=substr(s, RSTART, RLENGTH);
            } else if (match(s, /[0-9][0-9\\.a-zA-Z+-]*/)) {
                version=substr(s, RSTART, RLENGTH);
            }
        }
    }

    # FreeBayes detection
    /^##source=/ && caller=="" {
        s=substr(\$0,10);
        if (match(s, /freeBayes/)) {
            caller="FreeBayes";
            if (match(s, /v[0-9][0-9\\.a-zA-Z+-]*/)) {
                version=substr(s, RSTART, RLENGTH);
            }
        }
    }

    # Generic source parsing fallback
    /^##source=/ && caller=="" {
        s=substr(\$0,10);
        # Extract first word as caller name
        if (match(s, /^[^ ]+/)) {
            caller=substr(s, RSTART, RLENGTH);
        }
        # Try to extract version patterns
        if (version=="" && match(s, /v[0-9][0-9\\.a-zA-Z+-]*/)) {
            version=substr(s, RSTART, RLENGTH);
        } else if (version=="" && match(s, /[0-9][0-9\\.a-zA-Z+-]*/)) {
            version=substr(s, RSTART, RLENGTH);
        }
    }

    # Reference genome detection
    /^##reference=/ { 
        if (ref=="") ref=substr(\$0,13);
    }

    # Alternative reference patterns
    /^##contig=<ID=/ {
        if (ref=="" && match(\$0, /assembly=([^,>]+)/)) {
            ref=substr(\$0, RSTART+9, RLENGTH-9);
        }
    }

    END{
        # Use source as fallback for caller if nothing else found
        if (caller=="" && src!="") {
            if (match(src, /^[^ ]+/)) {
                caller=substr(src, RSTART, RLENGTH);
            } else {
                caller=src;
            }
        }
        
        # Clean up caller name (remove paths, keep only basename)
        if (match(caller, /[^\\/]+\$/)) {
            caller=substr(caller, RSTART, RLENGTH);
        }
        
        # Output results - keep original reference names
        print "caller\\t" (caller=="" ? "unknown" : caller) >> OUT;
        print "version\\t" (version=="" ? "unknown" : version) >> OUT;
        print "reference\\t" (ref=="" ? "unknown" : ref) >> OUT;
        if (cmd!="") print "command\\t" cmd >> OUT;
        if (src!="") print "source\\t" src >> OUT;
    }
    ' header.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.caller_meta.tsv
    echo -e "key\\tvalue" > ${prefix}.caller_meta.tsv
    echo -e "caller\\tunknown" >> ${prefix}.caller_meta.tsv
    echo -e "version\\tunknown" >> ${prefix}.caller_meta.tsv
    echo -e "reference\\tunknown" >> ${prefix}.caller_meta.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}