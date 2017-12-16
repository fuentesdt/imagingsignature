
C3DEXE=/rsrch2/ip/dtfuentes/bin/c3d
WORKDIR=ImageDatabase
ITKSNAP=vglrun /opt/apps/itksnap/itksnap-3.2.0-20141023-Linux-x86_64/bin/itksnap

# load data file
-include datalocation/dependencies
datalocation/dependencies: loaddata.sql
	$(MYSQL) --local-infile < $< 


	@echo sqlite3 -init $<
	sqlite3 list < loaddata.sql | sed 's/"//g;s/IPVL_research_anno\///g;s/.annotationSignature.nii.gz//g' >  $@
	
nifti: $(addprefix $(WORKDIR)/,$(addsuffix /image.nii.gz,$(ANNOTATIONS)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /annotation.nii.gz,$(ANNOTATIONS)))  
# pyradiomics needs uchar type
$(WORKDIR)/%/annotation.nii.gz: /FUS4/IPVL_research_anno/%.annotationSignature.nii.gz
	mkdir -p $(WORKDIR)/$*
	$(C3DEXE) $< -type uchar -o $@

$(WORKDIR)/%/image.nii.gz: /FUS4/IPVL_research/%
	mkdir -p $(WORKDIR)/$*
	DicomImageReadWrite  /FUS4/IPVL_research/$*  $(@D)/image.dcm $@ /dev/null

$(WORKDIR)/%/view:
	$(ITKSNAP) -g  $(WORKDIR)/$*/image.nii.gz -s  $(WORKDIR)/$*/annotation.nii.gz  
