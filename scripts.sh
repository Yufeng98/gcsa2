#!/bin/bash


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

# get the reference
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz
# and the 1000G VCF
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz
# and its index
wget ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz.tbi
# unpack the reference
gunzip hs37d5.fa.gz

for i in $(seq 1 22; echo X; echo Y)
do
  ../../vg/bin/vg construct -R $i -r hs37d5.fa \
     -v ALL.wgs.phase3_shapeit2_mvncall_integrated_v5c.20130502.sites.vcf.gz \
     -t 32 -m 50 > $i.vg
done

../../vg/bin/vg ids -j $(for i in $(seq 22; echo X; echo Y); do echo $i.vg; done)

for i in $(seq 1 22; echo X; echo Y)
do
  ../../vg/bin/vg mod -pl 16 -t 16 -e 4 ${i}.vg | vg mod -S -l 100 - > ${i}_e4.vg
  ../../vg/bin/vg kmers -gB -k 16 -F -H 1000000000 -T 1000000001 \
     -t 16 ${i}_e4.vg > chr${i}_e4.graph
  rm -f ${i}_e4.vg
done

../bin/build_gcsa -d 3 -o human_e4_d3 -v \
           $(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}_e4; done) \
           > log.txt 2> errors.txt

OUTPUT=../gcsa/reads_$1
rm -f $OUTPUT

for i in *.vg
do
  ../../vg/bin/vg sim -l $1 -n $(($(stat --printf="%s" $i)/10000)) -f $i >> $OUTPUT
done