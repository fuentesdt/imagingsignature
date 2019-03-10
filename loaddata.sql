-- mysql < loaddata.sql

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
insert ignore into RandomForestHCCResponse.crcmutations( MRN ,MutationalStatus ,MutationalStatusAPC , MutationalStatusKras, MutationalStatusp53 , ImageDate	 ,StudyUID      ,SeriesUIDVen ,SeriesACQVen)
SELECT aq.mrn, e.MutationalStatus,e.APC,e.Kras,e.TP53,aq.StudyDate,aq.StudyUID, aq.seriesUID, aq.acquisitionTime  FROM student_intern.aq_sop aq
LEFT JOIN
(
SELECT uploadID,
JSON_UNQUOTE(data->"$.""MRN""") "MRN",
JSON_UNQUOTE(data->"$.""Image Date""") "Image Date",
JSON_UNQUOTE(data->"$.""Im. Accession No.""") "Im. Accession No.",
JSON_UNQUOTE(data->"$.""Mutational status""") MutationalStatus,
JSON_UNQUOTE(data->"$.""APC""") "APC",
JSON_UNQUOTE(data->"$.""KRAS""") "KRAS",
JSON_UNQUOTE(data->"$.""TP53""") "TP53",
JSON_UNQUOTE(data->"$.""PIK3CA""") "PIK3CA",
JSON_UNQUOTE(data->"$.""note1""") "note1",
JSON_UNQUOTE(data->"$.""note2""") "note2",
JSON_UNQUOTE(data->"$.""Series""") "Series",
JSON_UNQUOTE(data->"$.""Images                  (art; pv)""") "Images (art; pv)",
JSON_UNQUOTE(data->"$.""met size (cm)""") "met size (cm)",
JSON_UNQUOTE(data->"$.""Ta""") "Ta",
JSON_UNQUOTE(data->"$.""Ta SD""") "Ta SD",
JSON_UNQUOTE(data->"$.""Liv_a""") "Liv_a",
JSON_UNQUOTE(data->"$.""Liv_a SD""") "Liv_a SD",
JSON_UNQUOTE(data->"$.""Aoa""") "Aoa",
JSON_UNQUOTE(data->"$.""Aoa_SD""") "Aoa_SD",
JSON_UNQUOTE(data->"$.""Liv_a-Ta/Ao""") "Liv_a-Ta/Ao",
JSON_UNQUOTE(data->"$.""mutation (Y=1/ N=0)  1""") "mutation (Y=1/ N=0) 1",
JSON_UNQUOTE(data->"$.""mutation (Y=1/ N=0) 2""") "mutation (Y=1/ N=0) 2",
JSON_UNQUOTE(data->"$.""Tv""") "Tv",
JSON_UNQUOTE(data->"$.""Tv SD""") "Tv SD",
JSON_UNQUOTE(data->"$.""Liv_v""") "Liv_v",
JSON_UNQUOTE(data->"$.""Liv_v SD""") "Liv_v SD",
JSON_UNQUOTE(data->"$.""Aov""") "Aov",
JSON_UNQUOTE(data->"$.""Aov_SD""") "Aov_SD",
JSON_UNQUOTE(data->"$.""Liv_v-Tv/Aov""") "Liv_v-Tv/Aov",
JSON_UNQUOTE(data->"$.""[Tv-Ta]/[AoA-AoV]""") "[Tv-Ta]/[AoA-AoV]",
JSON_UNQUOTE(data->"$.""margin: irregular=1; smooth =2; lobulated=3""") "margin: irregular=1; smooth =2; lobulated=3",
JSON_UNQUOTE(data->"$.""Rim enh (none=1; a=2; v=3; a+v =4)""") "Rim enh (none=1; a=2; v=3; a+v =4)",
JSON_UNQUOTE(data->"$.""Largest met (cm)""") "Largest met (cm)",
JSON_UNQUOTE(data->"$.""No. mets: """) "No. mets: ",
JSON_UNQUOTE(data->"$.""non liver Rec site""") "non liver Rec site",
JSON_UNQUOTE(data->"$.""Primary R=1; L=2""") "Primary R=1; L=2",
JSON_UNQUOTE(data->"$.""Death date""") "Death date",
JSON_UNQUOTE(data->"$.""Date of  recurrence""") "Date of recurrence",
JSON_UNQUOTE(data->"$.""Age""") "Age",
JSON_UNQUOTE(data->"$.""Sex""") "Sex",
JSON_UNQUOTE(data->"$.""Race""") "Race"
FROM ClinicalStudies.excelUpload
where uploadID = 111
) e
on aq.mrn = e.MRN and e.`Im. Accession No.` = aq.AccessionNumber and e.Series = aq.seriesNo and e.`Images (art; pv)` = aq.imageNo where aq.StudyUID != 'null';

-- | id | mrn     | AccessionNumber | StudyDate  | StudyUID                                             | seriesUID                                               | seriesNo | tot_images | SOP                                                      | imageNo | path | acquisitionTime | exposureTime | contentTime   | seriesTime    | studyTime     |


-- error check duplicates
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select * from RandomForestHCCResponse.crcmutations cm where cm.StudyUID=cm.SeriesUIDVen
                                            ) b );

insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select count(cm.mrn) numgrp from RandomForestHCCResponse.crcmutations cm group by cm.studyuid
                                            ) b  where b.numgrp=2 );


-- @thomas-nguyen-3 dataqa
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
  select cm.mrn,cm.imagedate ,cm.MutationalStatus, cm.MutationalStatusAPC, cm.MutationalStatusKras, cm.MutationalStatusp53,
         concat_WS('/','/rsrch1/ip/dtfuentes/github/imagingsignature/ImageDatabase',cm.mrn,REPLACE(cm.ImageDate, '-', ''),cm.StudyUID,'/Ven.raw.nii.gz') Image , 
         concat_WS('/','/rsrch1/ip/dtfuentes/github/imagingsignature/ImageDatabase',cm.mrn,REPLACE(cm.ImageDate, '-', ''),cm.StudyUID,'/Cascade/LABELSNN.nii.gz') Mask, 
         lk.labelID Label
   from  RandomForestHCCResponse.crcmutations   cm 
   join  RandomForestHCCResponse.liverLabelKey  lk on lk.labelID in (2);
END //
DELIMITER ;
-- mysql  -re "call RandomForestHCCResponse.CRCPyRadMatrix ();"     | sed "s/\t/,/g;s/NULL//g" > datalocation/pyradiomics.csv
