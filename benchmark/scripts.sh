#!/bin/bash



# Prepare dependency tools
cd ..
git clone --recursive https://github.com/vgteam/sdsl-lite.git
git clone --recursive https://github.com/vgteam/vg.git
cd vg
# build vg dependencies following README
. ./source_me.sh && make
cd ../sdsl-lite
bash install.sh
cd ../gcsa2
make -j
cd benchmark
make -j



# Prepare Datasets
# get the reference
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz
# and the 1000G VCF
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz
# and its index
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz.tbi
# unpack the reference
gunzip hs37d5.fa.gz

VG=../../vg/bin/vg



# Build the template graph
# Build variant graph chr22.vg
for i in 22
do
  $VG construct -R $i -r hs37d5.fa \
     -v ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz \
     -t 32 -m 50 > chr$i.vg
done

$VG ids -j $(for i in 22; do echo chr$i.vg; done)

# Prune variant graph chr22.vg and generate chr22_e4.graph
for i in 22
do
  $VG mod -pl 16 -t 16 -e 4 chr${i}.vg | $VG mod -S -l 100 - > ${i}_e4.vg
  $VG kmers -gB -k 16 -H 1000000000 -T 1000000001 \
     -t 16 ${i}_e4.vg > chr${i}_e4.graph
  rm -f ${i}_e4.vg
done

# Build graph compressed suffix array (gcsa) of the pruned variant graph chr22_e4.graph and generate human_e4_d3.gcsa
../bin/build_gcsa -d 3 -o human_e4_d3 -v \
           $(for i in 22; do echo chr${i}_e4; done) \
           > log.txt 2> errors.txt



# Build the query sequence
# Simulate reads with $1 base pair length and generate read_$1
OUTPUT=reads_$1
rm -f $OUTPUT
for i in *.vg
do
  $VG sim -l $1 -n $(($(stat --printf="%s" $i)/10000)) -x $i >> $OUTPUT
done



# Execute the GCSA benchmark
# Query the reads on human_e4_d3 gcsa
./query_gcsa human_e4_d3 reads_$1



# # Build the template graph for all 1-22 and X Y chromosomes
# # Build variant graph chr1-chrY.vg
# for i in $(seq 1 22; echo X; echo Y)
# do
#   $VG construct -R $i -r hs37d5.fa \
#      -v ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz \
#      -t 32 -m 50 > chr$i.vg
# done

# $VG ids -j $(for i in $(seq 1 22; echo X; echo Y); do echo chr$i.vg; done)


# # Prune variant graph chr1-chrY.vg and generate chr1-chrY_e4.graph
# for i in $(seq 1 22; echo X; echo Y)
# do
#   $VG mod -pl 16 -t 16 -e 4 chr${i}.vg | $VG mod -S -l 100 - > ${i}_e4.vg
#   $VG kmers -gB -k 16 -H 1000000000 -T 1000000001 \
#      -t 16 ${i}_e4.vg > chr${i}_e4.graph
#   rm -f ${i}_e4.vg
# done

# # Build graph compressed suffix array (gcsa) of the pruned variant graph chr1-chrY_e4.graph and generate human_e4_d3.gcsa
# ../bin/build_gcsa -d 3 -o human_e4_d3 -v \
#            $(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}_e4; done) \
#            > log.txt 2> errors.txt

# # Simulate reads with $1 base pair length and generate read_$1
# OUTPUT=reads_$1
# rm -f $OUTPUT
# for i in *.vg
# do
#   $VG sim -l $1 -n $(($(stat --printf="%s" $i)/10000)) -x $i >> $OUTPUT
# done

# # Query the reads on human_e4_d3 gcsa
# ./query_gcsa human_e4_d3 reads_$1