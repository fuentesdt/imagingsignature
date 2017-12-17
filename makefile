ROOTDIR=/rsrch1/ip/dtfuentes/github/imagingsignature
C3DEXE=/rsrch2/ip/dtfuentes/bin/c3d
WORKDIR=ImageDatabase
ITKSNAP=vglrun /opt/apps/itksnap/itksnap-3.2.0-20141023-Linux-x86_64/bin/itksnap

# load data file
-include $(ROOTDIR)/datalocation/dependencies
datalocation/dependencies: loaddata.sql
	$(MYSQL) --local-infile < $< 
	$(MYSQL) -sNre "call RandomForestHCCResponse.CRCMutDependencies();"  > $@

	
nifti: $(addprefix $(WORKDIR)/,$(addsuffix /image.nii.gz,$(ANNOTATIONS)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /annotation.nii.gz,$(ANNOTATIONS)))  
# pyradiomics needs uchar type
$(WORKDIR)/%/annotation.nii.gz: /FUS4/IPVL_research_anno/%.annotationSignature.nii.gz $(WORKDIR)/%/image.nii.gz
	mkdir -p $(WORKDIR)/$*
	$(C3DEXE) $(word 2,$^) $< -copy-transform -type uchar -o $@

$(WORKDIR)/%/image.nii.gz: /FUS4/IPVL_research/%
	mkdir -p $(WORKDIR)/$*
	DicomImageReadWrite  /FUS4/IPVL_research/$*  $(@D)/image.dcm $@ /dev/null
	$(C3DEXE) $@ -type float -o $@

$(WORKDIR)/%/view:
	$(ITKSNAP) -g  $(WORKDIR)/$*/image.nii.gz -s  $(WORKDIR)/$*/annotation.nii.gz  
