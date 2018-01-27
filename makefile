SHELL := /bin/bash
ROOTDIR=/rsrch1/ip/dtfuentes/github/imagingsignature
C3DEXE=/rsrch2/ip/dtfuentes/bin/c3d
WORKDIR=ImageDatabase
ITKSNAP=vglrun /opt/apps/itksnap/itksnap-3.2.0-20141023-Linux-x86_64/bin/itksnap
DCMNIFTISPLIT=/rsrch1/ip/dtfuentes/github/FileConversionScripts/seriesreadwriteall/DicomSeriesReadImageWriteAll

# load data file
-include $(ROOTDIR)/datalocation/dependencies
datalocation/dependencies: loaddata.sql
	$(MYSQL) --local-infile < $< 
	$(MYSQL) -sNre "call RandomForestHCCResponse.CRCMutDependencies();"  > $@

nifti:  $(RAWVEN)
#nifti:   $(addprefix $(WORKDIR)/,$(addsuffix /Ven.raw.nii.gz,$(CRCMETTRAIN)))
#nifti:   $(addprefix $(WORKDIR)/,$(addsuffix /Ven.raw.nii.gz,$(CRCMETTEST)))
#nnmodels:     $(addprefix $(WORKDIR)/,$(addsuffix /Cascade/LABELSNN.nii.gz,$(CRCMETTRAIN)))
nnmodels:   $(addprefix $(WORKDIR)/,$(addsuffix /Cascade/LABELSNN.nii.gz,$(CRCMETTRAIN))) $(addprefix $(WORKDIR)/,$(addsuffix /Cascade/LABELSNN.nii.gz,$(CRCMETTEST)))

checkxfer:  
	ls $(addprefix $(WORKDIR)/,$(addsuffix /Ven.raw.nii.gz,$(CRCMETTRAIN))) | wc

$(WORKDIR)/%/raw.xfer:
	mkdir -p $(@D)
	# when using -B option to rebuild from scratch, skip network file system access if files available
	if [ ! -d /FUS4/IPVL_research/$*  ] ; then \
          if [ `date +%H` -le 6 ] || [ `date +%H` -ge 17 ] || [[ `date +%A` == "Saturday" ]] || [[ `date +%A` == "Sunday" ]]; then \
            movescu -v -S -k 0008,0052=SERIES -aet ipvl_research -aec Stentor_QRP 192.168.5.55 107 -k 0020,000d=$(word 3,$(subst /, ,$*)) -k 0020,000e=$(lastword  $(subst /, ,$*)); else echo 'waiting for off-peak hours... ';  fi; else echo skipping network filesystem; fi
	if [   -d /FUS4/IPVL_research/$*  ] ; then touch -r /FUS4/IPVL_research/$* $@  ; fi
	
# pyradiomics needs uchar type
# apply deep learning model 
$(WORKDIR)/%/Cascade/LABELSNN.nii.gz: 
	mkdir -p $(@D)
	python ./cascaded_unet_inference.py --imagefile=$(WORKDIR)/$*/Ven.raw.nii.gz --segmentation=$@

$(WORKDIR)/%/view:
	$(ITKSNAP) -g  $(WORKDIR)/$*/Ven.raw.nii.gz -s  $(WORKDIR)/$*/Cascade/LABELSNN.nii.gz
