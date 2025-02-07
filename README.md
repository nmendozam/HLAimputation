![](images/ikmb_bfx_logo.png)



NOTE: THIS IS A BETA VERSION AND SOME THINGS STILL NEED TO BE UPDATED (I.E. AMINO ACID POSITIONS)
 
# HLApipePublic


This pipeline offers a workflow for HLA imputation using HIBAG (Zheng et al., 2014) and phasing for small datasets (Degenhardt et al., 2021) including utility scripts to evaluate the accuracy of the imputation. It is designed to work within a computing cluster. For specific requirements see the .config files below.

Preprocessing:
- Alignment of a study to the imputation reference

Main:
- HLA, Amino acid (AA) & SNP imputation (Note that DRB3/4/5 positions were mapped to DRB1 for sake of simplicity; the last 3 AA of DRB1/3/4/5 and DQB1 are mapped to position 0, they are not present in the nucleotide reference of the genes)
- Phasing of HLA alleles


Other: 
- Calculation of marginal probabilitites per allele of imputation results
- Calculation of alleles that have similar SNP haplotypes given the positions in your input data
- Calculation of alleles that are difficult to phase given your input data

Utility code includes (folder: utility): 
- Preparation of SNP/AA database from the IDP-IMGT/HLA database  [https://www.ebi.ac.uk/ipd/imgt/hla/]. At the moment generation is supported for HLA-A, -B, -C, -DPA1, -DPB1, -DQA1, -DQB1 and -DRB1/3/4/5
- Plotting of results from an HLA analysis including SNPs (it is recommended that association results of SNPs from the HLA region, i.e. from TopMed imputation are merged to association results from HLA allele association)

IMPORTANT NOTE: The reference for amino acids and nucleotids always is built from the longest nucleotide or amino acid sequence present for an HLA allele across the 2-,3- and 4-fields present in the alignments of the IDP-IMGT/HLA database.

## Dependencies 

- Nextflow
- SHAPEIT2 [https://mathgen.stats.ox.ac.uk/genetics_software/shapeit/shapeit.html#download]
- IMPUTE2 reference. [https://mathgen.stats.ox.ac.uk/impute/impute_v2.html#reference]
- BEAGLE (optional) [https://faculty.washington.edu/browning/beagle/b4_1.html]
- Beagle map plink.chr6.GRCh37.map [http://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/]
- PLINK 1.9 [https://www.cog-genomics.org/plink/1.9/]
- R (version 3.5+)
- R packages: as specified in environment.yml

## Installation

Change the following lines in the nextflow.config files (https://www.nextflow.io/docs/latest/config.html) files to fit your requirements. Especially make sure that the time limit of your computing cluster allows the max_time runtime and that the storage (memory) and CPU requirements fit.

nextflow.config:

```
params.impute2_reference_dir = /path/to/impute2/reference/files
params.ref_1000G =  /path/to/1000G/.bim/.bed/.fam annotation
params.shapeit = /path/to/shapeit2/executable
```

```
params {
  // Defaults only, expecting to be overwritten
  max_memory = 120.GB
  max_cpus = 8
  max_time = 36.h
  maxMultiqcEmailFileSize = 25.MB 
}
```

conf/base.config
```
 // Global cluster parameters
  cpus = { check_max( 1 * task.attempt, 'cpus' ) }
  memory = { check_max( 8.GB * task.attempt, 'memory' ) }
  time = { check_max( 2.h * task.attempt, 'time' ) }

  errorStrategy = { task.exitStatus in [143,137,140,7] ? 'retry' : 'finish' }
  maxRetries = 3
  maxErrors = '-1'

  // Specific cluster parameters for each process

  // software dependencies moved to conda.config

  withName:imputeHLA {
        memory = { check_max( 120.GB * task.attempt, 'memory' ) }
        time = { check_max( 120.h * task.attempt, 'time' ) }
        cpus = { check_max( 16 , 'cpus' ) }
  }
  withName:phaseSNPs {
        memory = { check_max( 10.GB * task.attempt, 'memory' ) }
        time = { check_max( 120.h * task.attempt, 'time' ) }
        cpus = { check_max( 8 , 'cpus' ) }
  }
  withName:phaseHLA {
	memory = { check_max( 50.GB * task.attempt, 'memory' ) }
        time = { check_max( 48.h * task.attempt, 'time' ) }
        cpus = { check_max( 8 , 'cpus' ) }
  }
  withName:imputeHLACombine {
        memory = { check_max( 50.GB * task.attempt, 'memory' ) }
        time = { check_max( 48.h * task.attempt, 'time' ) }
  }
  withName:phaseHLACombine {
        memory = { check_max( 20.GB * task.attempt, 'memory' ) }
        time = { check_max( 48.h * task.attempt, 'time' ) }
  }

```

Running the Pipeline in a cluster system. Edit your $HOME/.nextflow/config as follow (if this file does not exist yet, create it):

```
// bind work directories (i.e. work_ifs). 
// If you need more than $HOME and work_ifs, add another "-B /somewhere" switch.
singularity.runOptions = "-B /work_ifs"

// make nextflow use slurm by default, specify the right queue size and the queue name
profiles {
    standard {
        executor.name = "slurm"
        executor.queueSize = 150
        process.executor = "slurm"
        process.queue = "all"
    }
}

```

- R packages and PLINK can be installed using anaconda and 
```
conda env create -f environment.yml
conda activate hla-pipe-1.0
```
- Download plink.chr6.GRCh37.map from [https://bochet.gcc.biostat.washington.edu/beagle/genetic_maps/] and place it into assets/beagle_map/


## Usage

### Basic execution
```
Usage:  nextflow run HLApipePublic --prefix FILE --reference_name REFERENCE --run_name NAME --shapeit SHAPEIT --impute2_reference_dir IMPUTE2_REF_DIR 
```
### Parameters

```--prefix```		An input prefix referencing a set of PLINK files \

```--reference_name``` 	Name of the reference imputation panel (see below for details) 

### Optional parameters:

General:

```--loci```     	Loci that should be imputed. Comma-sparated. e.g. DPA1,DPB1,DQA1 Default: As specified in conf/resources.config.\


Software/References: 

```--shapeit```		Path to the SHAPEIT2 executable. \
```--impute2_ref_dir``` Path to the IMPUTE2 reference. \
```--beagle```        Location of the .jar file of BEAGLE4.1. \
```--do_beagle```    	This flag is optional and enables phasing using Beagle. Default: false. \
```--ref_1000G ```    Path to population used for PCA. PLINK files (hg19). Default: 1000G Phase 3 population. \
```--sample```	Path to sample file used for PCA. Default: 1000G Phase 3 population. \
```--subpop```    	Name of a sub population to use. Valid options are: AA, AFR, AMR, CHN, EAS, EUR, GER, IND, IRN, JPN, KOR, MLT. Can be used together with the IKMB reference.\

Others: 

```--email```         Email address to send reports to (enclosed in '') \
```--outdir```        Path to output directory. Default: results.

## Input formats
- PLINK file in .bed/.bim/.fam format. Assembly must be the same as the assembly of the reference. Default here hg19.

## Example 

- Example data are stored in the directory "example" that can be downloaded with this repository. These example data
are trio-individuals [Utah Residents (CEPH) with Northern and Western European Ancestry (CEU)] extracted from the Hapmap Phase 3 project and HLA allele information published for these individuals in the 1000 Genomes HLA diversity panel (Gourrard et al., 2014) (extracted from ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/working/20140725_hla_genotypes/20140702_hla_diversity.txt). See Degenhardt et al., 2021 for details. 

```
nextflow run HLApipePublic --prefix example/trio_CEU --reference_name GSA_Broad --run_name gsa_broad --loci DPB1,DQA1,DQB1 --shapeit SHAPEIT --impute2_reference_dir IMPUTE2_REF_DIR --do_beagle false -resume
```

## Output formats
Imputed HLA alleles, SNPs and amino acids. 

**Notation**: 

*alleles*: A*01:01 corresponds to imputed_A_01_01. 
*nucleotides*: imputed_gene_hg19bp_alelle1_allele2; 
*prot*: imputed_gene_AAposition_allele1_allele2. For multiallelic markers: allele2 is a list of the alternatives (separated by "or" to the reference allele1).
For prot: the position of the AA was mapped back to the genome. 

NOTE: For joint analysis with original PLINK input, output files form this pipeline have to be merged with the data from the PLINK input. 


<details> <summary>.*html </summary>
Detailed and graphical output of the pipeline, showing the alignment of your input data to the reference model based on allele frequencies, different measures for imputation and phasing accuracy.
</details>
	
<details> <summary>
alignToReference: .*.summary.refchecked.txt</summary>

| Name  | Description |
| ------------- | ------------- |
| chr | chromosome in input file|
| id | SNP id in input file  |
| pos | position (bp) in input file  |
| A1| minor allele in input file  |
| A2 | major allele in input file  |
| MAF | minor allele frequency in input file |
| ref.pos | position (bp) in reference model  |
| ref.A1 |  minor allele in reference model|
| ref.A2 | major allele in reference model  |
| ref.MAF | minor allele frequency in reference model  |
| action | action taken |
| type | type of genotype AT/CG or not |
</details>
<details> <summary>
imputeHLA: .*marginal_prob.*.txt</summary>

| Name  | Description |
| ------------- | ------------- |
| locus| HLA locus|
| id | HLA allele code |
| prob | marginal posterior probability cauclated from the HIBAG model |
| freq | frequency of the HLA allele  |
| digits | calculated for X digits  |

</details>

<details> <summary>
imputeHLA: .*overlap_alleles.*.txt</summary>
	
| Name  | Description |
| ------------- | ------------- |
| gene| HLA locus|
| alleles | HLA allele code; compared allele combination |
| 0%-100%| min (0%), max (100%) and quartiles (25%, 50%, 75%) of the % position overlap for N classifiers|
| NClassifiers | Number of classifiers |

</details>

<details> <summary>
phaseHLA: .*info</summary>
	
| Name  | Description |
| ------------- | ------------- |
| chr | chromosome in input file|
| id | of HLA allele or HLA haplotype  |
| pos | position (bp)  |
| REF| reference allele (A = Absent)  |
| ALT | alternative allele (P = Present)  |
| AF_ALL,\_CASE,\_CONTROL,\_UKN | allele frequency: all, cases only, controls only or individuals with unknown status |
| SAMPLES_ALL,\_CASE,\_CONTROL,\_UKN  | Number of individuals: all, all, cases only, controls only or individuals with unknown status |
| P_HWE_CONTROL | P-value of conformity with Hardy-Weinberg Equilibrium in controls 
</details>

<details> <summary>
phaseHLA: .*RData</summary>
	
| Name  | Description |
| ------------- | ------------- |
| chr | chromosome in input file|
| id | of HLA allele or HLA haplotype  |
| pos | position (bp)  |
| REF| reference allele (A = Absent)  |
| ALT | alternative allele (P = Present)  |
| COLUMNS AFTER | sample ids|

For each sample the dose 0,1,2 of presence (P) of the allele is given. Haplotypes were only constructed for alleles with a phasing cerainty > 0.8 per sample (i.e. if one allele in a haplotype had phasing certainty <0.8 the whole haplotype was not built). 
</details>


<details> <summary>
phaseHLA: .*csv</summary>
	
| Name  | Description |
| ------------- | ------------- |
| IID |	sample id | 
| haplotype | both parental haplotypes for different HLA genes | 

Haplotypes were only constructed for alleles with a phasing cerainty > 0.8 per sample (i.e. if one allele in a haplotype had phasing certainty <0.8 the whole haplotype was not built).
</details>


<details> <summary>
phaseHLA: .*ped/.map/.bed/.bim/.fam </summary>
PLINK file format [https://www.cog-genomics.org/plink/1.9/].
</details>

<details> <summary>
phaseHLA: .*META.PHASING.txt</summary>
	
| Name  | Description |
| ------------- | ------------- |
| IID | sample id |
| locus | HLA locus  |
| X1 | HLA allele assigned to parental chromosome 1 |
| X2 | HLA allele assigned to parental chromosome 2  |
| true_geno | the real (but unphased) HLA alleles; if phasing did not work X1 may be equal to X2|
| phase_prob | phasing probability  |
| min_diff_1 | median minimal hemming distance for genotyped/phased (SHAPEIT) SNP haplotypes of X1 to SNP haplotypes stored in the HIBAG model; [min,max]|  
| min_diff_2 | see above but for X2 | 
| pos_used |  median number of SNP positions used to make the assignments for X1 and X2; [min, max] |
| shapeit_1/2_prob| median minimal phasing probability (SHAPEIT) of genotyped SNPs within the gene locus; [min,max] |
| imputation_prob| HIBAG post-imputation probability for the HLA genotype (true.geno) |


All given statistics are per sample statistics.
</details>


## HLA reference panels

###  Add a reference

To add a reference, make an entry into conf/resources.config. 

| Name  | Description |
| ------------- | ------------- |
| model | path to the HIBAG RData object|
| loci | loci for which the HIBAG model was trained  |
| dict| path to the dictionary RData object for imputation of amino acids and SNP from HLA allele information (see below) |

```
	'IKMB' {
		model = "${baseDir}/assets/models/multiethnic_IKMB/model_multiethnic.RData"
		loci = ["A","B","C","DRB1","DQA1","DQB1","DPA1","DPB1","DRB3","DRB4","DRB5"]
		dict =${baseDir}/assets/supplementary/impute_SNPs_AA_full.RData"
	}
  
```

## Amino acid and SNP Dictionary

The current dictionaries include impute_SNPs_AA_full.RData and impute_SNPs_AA_G.RData. The former is a lookup for for-digit full context HLA alleles, the latter is based on G-groups (http://hla.alleles.org).

Scripts to create a new dictionary are contained in the util folder. 

- Download the alignments folder from the IMGT-HLA github (https://github.com/ANHIG/IMGTHLA.git) and place folder into util/alignments.
- Download hla_nom_g.txt from http://hla.alleles.org and place into util.
- Download Allele_status.txt from the IMGT-HLA github (https://github.com/ANHIG/IMGTHLA.git) and place into util.

```
cd util
Rscript scripts/prepare_alignment.R alignments reference scripts 
```
Place the newly created impute_SNPs_AA_full.RData and impute_SNPs_AA_G.RData into assets/supplementary.

## REFERENCES
- Degenhardt F, Wendorff M, et al. Construction and benchmarking of a multi-ethnic reference panel for the imputation of HLA class I and II alleles. Hum Mol Genet. 2019 Jun 15;28(12):2078-2092. doi: 10.1093/hmg/ddy443. PMID: 30590525; PMCID: PMC6548229.
- Degenhardt F, et al.; International IBD Genetics Consortium. Transethnic analysis of the human leukocyte antigen region for ulcerative colitis reveals not only shared but also ethnicity-specific disease associations. Hum Mol Genet. 2021 Apr 27;30(5):356-369. doi: 10.1093/hmg/ddab017. PMID: 33555323; PMCID: PMC8098114.
- Zheng X, Shen J, Cox C, Wakefield JC, Ehm MG, Nelson MR, Weir BS. HIBAG--HLA genotype imputation with attribute bagging. Pharmacogenomics J. 2014 Apr;14(2):192-200. doi: 10.1038/tpj.2013.18. Epub 2013 May 28. PMID: 23712092; PMCID: PMC3772955.
- Purcell S, Neale B, Todd-Brown K, Thomas L, Ferreira MA, Bender D, Maller J, Sklar P, de Bakker PI, Daly MJ, Sham PC. PLINK: a tool set for whole-genome association and population-based linkage analyses. Am J Hum Genet. 2007 Sep;81(3):559-75. doi: 10.1086/519795. Epub 2007 Jul 25. PMID: 17701901; PMCID: PMC1950838.
- Delaneau O, Marchini J, Zagury JF. A linear complexity phasing method for thousands of genomes. Nat Methods. 2011 Dec 4;9(2):179-81. doi: 10.1038/nmeth.1785. PMID: 22138821.
- The 1000 Genomes Project Consortium. A global reference for human genetic variation. Nature 526, 68–74 (2015). https://doi.org/10.1038/nature15393
- Howie BN, Donnelly P, Marchini J. A flexible and accurate genotype imputation method for the next generation of genome-wide association studies. PLoS Genet. 2009 Jun;5(6):e1000529. doi: 10.1371/journal.pgen.1000529. Epub 2009 Jun 19. PMID: 19543373; PMCID: PMC2689936.
- Browning BL, Zhou Y, Browning SR. A One-Penny Imputed Genome from Next-Generation Reference Panels. Am J Hum Genet. 2018 Sep 6;103(3):338-348. doi: 10.1016/j.ajhg.2018.07.015. Epub 2018 Aug 9. PMID: 30100085; PMCID: PMC6128308.
- Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820. PMID: 28398311.
- Gourraud PA, Khankhanian P, Cereb N, Yang SY, Feolo M, Maiers M, Rioux JD, Hauser S, Oksenberg J. HLA diversity in the 1000 genomes dataset. PLoS One. 2014 Jul 2;9(7):e97282. doi: 10.1371/journal.pone.0097282. PMID: 24988075; PMCID: PMC4079705.









