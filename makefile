


# load data file
-include datalocation/dependencies
datalocation/dependencies: loaddata.sql
	@echo sqlite3 -init $<
	sqlite3 list < loaddata.sql | sed 's/"//g;s/IPVL_research_anno\///g;s/.annotationSignature.nii.gz//g' >  $@
