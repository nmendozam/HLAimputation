params.samples = false
params.reference = false


process HLAimputation {
    container 'nmendozam/hla-tapas'
    input:
        path input
        path reference
    output:
        path out
    script:
        out = "${input.baseName}.imputed"

        if (!reference) {
            reference = "/usr/share/HLA-TAPAS/resoruces/1000G.bglv4.bgl.phased.vcf.gz"
        }

        """
        mkdir -p $out
        python -m SNP2HLA
            --target $input.baseName
            --out $out
            --reference $reference
            --nthreads $task.cpus
            --mem $task.mem
        """
}

workflow {
    if (!params.samples) {
        error "Error: missing csv file --samples"
    }

    // Get the list of samples from csv file
    samples = Channel.fromPath(params.samples)
                .splitCsv(header: true)

    // print the list of samples
    samples.view()

    if (params.reference) {
        reference_files = Channel.fromPath(params.reference + "{,.tbi}")
        HLAimputation(samples, reference_files)
    } else {
        print "Using default reference panel"
        HLAimputation(samples, params.reference)
    }

}