-- mysql --local-infile < loaddata.sql

use RandomForestHCCResponse;
DROP TABLE IF EXISTS RandomForestHCCResponse.crcmutations;
CREATE TABLE RandomForestHCCResponse.crcmutations(
  MRN	             int not null,
  MutationalStatus     VARCHAR(32)     not null,
  MutationalStatusAPC  VARCHAR(32)     not null,
  MutationalStatusKras VARCHAR(32)     not null,
  MutationalStatusp53  VARCHAR(32)     not null,
  ImageDate	             DATE         NULL COMMENT 'Study Date',
  StudyUID            VARCHAR(256)    not NULL  COMMENT 'study UID'              ,
  SeriesUIDVen        VARCHAR(256)         NULL  COMMENT 'series UID'             ,
  SeriesACQVen        VARCHAR(256)         NULL  COMMENT 'series acquisition time',
  NotRun                    int            NULL  COMMENT 'error checking ',
  PRIMARY KEY (StudyUID) 
);

-- ignore duplicates
insert ignore into RandomForestHCCResponse.crcmutations( MRN ,MutationalStatus ,ImageDate	 ,StudyUID      ,SeriesUIDVen ,SeriesACQVen)
 SELECT JSON_UNQUOTE(eu.data->"$.""MRN""") MRN,
         JSON_UNQUOTE(data->"$.""Triple status""") MutationalStatus , 
         JSON_UNQUOTE(eu.data->"$.""Image Date""") ImageDate,
         JSON_UNQUOTE(eu.data->"$.""Study UID""") StudyUID,
         replace(substring_index( json_unquote(eu.data->'$."VEN Series UID"'), ':', 1),'{','') SeriesUIDVen,
         replace(substring_index( json_unquote(eu.data->'$."VEN Series UID"'), ':',-1),'}','') SeriesACQVen 
         FROM ClinicalStudies.excelUpload eu where eu.uploadID = 84  and JSON_UNQUOTE(eu.data->"$.""Study UID""") is not null;

-- fixme need single table
update RandomForestHCCResponse.crcmutations rf
  join ClinicalStudies.excelUpload eu   on (eu.uploadID=87 and rf.MRN = JSON_UNQUOTE(eu.data->"$.""MRN""") )
   SET rf.MutationalStatusAPC=JSON_UNQUOTE(eu.data->"$.""APC""")   ,
       rf.MutationalStatusKras=JSON_UNQUOTE(eu.data->"$.""Kras""") , 
       rf.MutationalStatusp53 =JSON_UNQUOTE(eu.data->"$.""p53""") , 
       rf.NotRun  = JSON_UNQUOTE(eu.data->"$.""Not Run""") ;


-- error check duplicates
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select * from RandomForestHCCResponse.crcmutations cm where cm.StudyUID=cm.SeriesUIDVen
                                            ) b );

-- verify 14 WT  did not get deleted on insert
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select count( rf.StudyUID) numtruth from RandomForestHCCResponse.crcmutations rf where rf.MutationalStatus = 'WT'
                                   ) b on b.numtruth !=14 );

-- verify 24 mut  did not get deleted on insert
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select count( rf.StudyUID) numtruth from RandomForestHCCResponse.crcmutations rf where rf.MutationalStatus = 'mut'
                                   ) b on b.numtruth !=24 );

-- use dicomheaders as dflt study date for each
update RandomForestHCCResponse.crcmutations rf
  join DICOMHeaders.studies  sd     on sd.StudyInstanceUID=rf.StudyUID
   SET rf.ImageDate=coalesce(sd.StudyDate,rf.ImageDate);



DROP PROCEDURE IF EXISTS RandomForestHCCResponse.CRCMutDependencies;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.CRCMutDependencies
()
BEGIN
  SET SESSION group_concat_max_len = 10000000;
  
    select concat("NUMCRCMET =",count(rf.studyUID)) from RandomForestHCCResponse.crcmutations rf;
    select concat("CRCMETTRAIN =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.ImageDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.crcmutations rf
    where rf.SeriesACQVen is not null and (rf.MutationalStatus = 'WT' or rf.MutationalStatus = 'mut');
    select concat("CRCMETTEST =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.ImageDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.crcmutations rf
    where rf.SeriesACQVen is not null and (rf.MutationalStatus != 'WT' and rf.MutationalStatus != 'mut');
    select concat("CRCMETNOTRUN =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.ImageDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.crcmutations rf
    where rf.NotRun =1; 

    select concat("NUMRAWVEN =",count(rf.SeriesACQVen)) from RandomForestHCCResponse.crcmutations rf where rf.SeriesACQVen is not null and rf.ImageDate is not null ;
    select concat("RAWVEN  =", group_concat( distinct
           CONCAT_WS('/','ImageDatabase', rf.mrn,  REPLACE(rf.ImageDate, '-', ''), rf.StudyUID, 'Ven.raw.nii.gz ' ) 
                              separator ' ') )
    from RandomForestHCCResponse.crcmutations rf
    where rf.SeriesACQVen is not null and rf.ImageDate is not null ;

    -- convert to nifti 
    select CONCAT('ImageDatabase/', a.mrn, '/', REPLACE(a.StudyDate, '-', ''),'/', a.StudyUID, '/', a.Phase ,'.raw.nii.gz: ImageDatabase/', a.mrn, '/', REPLACE(a.StudyDate, '-', ''),'/', a.StudyUID, '/',a.SeriesUID, '/raw.xfer \n\tif [ ! -f ImageDatabase/', a.mrn, '/', REPLACE(a.StudyDate, '-', ''),'/', a.StudyUID, '/',a.SeriesUID,'/',a.SeriesACQ,'.nii.gz   ] ; then mkdir -p ImageDatabase/', a.mrn, '/', REPLACE(a.StudyDate, '-', ''),'/', a.StudyUID, '/',a.SeriesUID,' ;$(DCMNIFTISPLIT) $(subst ImageDatabase,/FUS4/IPVL_research,$(<D)) $(@D)  \'0008|0032\' ; else echo skipping network filesystem; fi\n\tln -snf ./',a.SeriesUID,'/',a.SeriesACQ,'.nii.gz $@; touch -h -r $(@D)/',a.SeriesUID,'/',a.SeriesACQ,'.nii.gz  $@;\n\tln -snf ./',a.SeriesUID,'/ $(subst .nii.gz,.dir,$@)') 
    from (
          select rf.mrn,'Ven' as Phase,rf.Imagedate as StudyDate,rf.StudyUID as StudyUID,rf.SeriesUIDVen as SeriesUID,rf.SeriesACQVen as SeriesACQ from RandomForestHCCResponse.crcmutations rf
         ) a
    where a.SeriesACQ is not null 
    group by a.SeriesUID, a.SeriesACQ;
END //
DELIMITER ;

-- show create procedure RandomForestHCCResponse.CRCMutDependencies;
-- mysql  -sNre  "call RandomForestHCCResponse.CRCMutDependencies();"| sed "s/NULL//g" >  datalocation/dependencies

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.CRCPyRadMatrix ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.CRCPyRadMatrix 
(  )
BEGIN
   -- select  a.mrn, a.TIMEID, sd.studyInstanceUID, lk.location,  
  select cm.mrn,cm.imagedate ,cm.MutationalStatus, 
         concat_WS('/','/rsrch1/ip/dtfuentes/github/imagingsignature/ImageDatabase',cm.mrn,REPLACE(cm.ImageDate, '-', ''),cm.StudyUID,'/Ven.raw.nii.gz') Image , 
         concat_WS('/','/rsrch1/ip/dtfuentes/github/imagingsignature/ImageDatabase',cm.mrn,REPLACE(cm.ImageDate, '-', ''),cm.StudyUID,'/Cascade/LABELSNN.nii.gz') Mask, 
         lk.labelID Label
   from  RandomForestHCCResponse.crcmutations   cm 
   join  RandomForestHCCResponse.liverLabelKey  lk on lk.labelID in (2);
END //
DELIMITER ;
-- mysql  -re "call RandomForestHCCResponse.CRCPyRadMatrix ();"     | sed "s/\t/,/g;s/NULL//g" > datalocation/pyradiomics.csv
