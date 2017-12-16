use RandomForestHCCResponse;
DROP TABLE IF EXISTS RandomForestHCCResponse.crcmutations;
CREATE TABLE RandomForestHCCResponse.crcmutations(
  MRN	             int not null,
  ImageDate	             date not null,
  AccessionNumber             int not null,
  MutationalStatus             text not null,
  APC             int not null,
  KRAS             int not null,
  TP53             int not null,
  PIK3CA             int not null 
) SELECT JSON_UNQUOTE(data->"$.""MRN""") MRN,
       JSON_UNQUOTE(data->"$.""Image Date""") ImageDate,
       JSON_UNQUOTE(data->"$.""Image Accession Number""") ImageAccession,
       JSON_UNQUOTE(data->"$.""Mutational status""") MutationalStatus,
       JSON_UNQUOTE(data->"$.""APC""")  APC,
       JSON_UNQUOTE(data->"$.""KRAS""") KRAS,
       JSON_UNQUOTE(data->"$.""TP53""") TP53,
       JSON_UNQUOTE(data->"$.""PIK3CA""") PIK3CA
       FROM ClinicalStudies.excelUpload where uploadID = 79 and JSON_UNQUOTE(data->"$.""MRN""")  is not null;



DROP TABLE IF EXISTS RandomForestHCCResponse.crcannotations;
CREATE TABLE RandomForestHCCResponse.crcannotations(
  mrn              int   GENERATED ALWAYS AS ( substring_index(substring_index(niftypath,'/',2),'/',-1) ) COMMENT 'PT UID'                    ,
  Image            text  GENERATED ALWAYS AS ( replace(substring_index(substring_index(ca.niftypath,'/',6),'/',-5),'.annotationSignature.nii.gz','/image.nii.gz')     ) COMMENT 'image file',
  Mask             text  GENERATED ALWAYS AS ( replace(substring_index(substring_index(ca.niftypath,'/',6),'/',-5),'.annotationSignature.nii.gz','/annotation.nii.gz')) COMMENT 'mask file',
  filename         TEXT NOT NULL,
  niftypath         TEXT NOT NULL,
  ReferenceSOPUID   TEXT NOT NULL,
  StudyUID         TEXT NOT NULL,
  SeriesUID         TEXT NOT NULL,
  StudyDate         Date NOT NULL
);
-- load data
LOAD DATA LOCAL INFILE 'datalocation/phiannotations.csv'
INTO TABLE RandomForestHCCResponse.crcannotations
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
( filename        , niftypath       , ReferenceSOPUID , StudyUID        , SeriesUID       , StudyDate       );
-- SET scandate = STR_TO_DATE(@var1,'%m/%d/%Y'),fustudydate = STR_TO_DATE(@fustudydate,'%m/%d/%Y'), LesionLocation='RT FRONTAL' ;


DROP PROCEDURE IF EXISTS RandomForestHCCResponse.CRCMutDependencies;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.CRCMutDependencies
()
BEGIN
  select concat("ANNOTATIONS=" , group_concat(an.niftypath,' ')) from RandomForestHCCResponse.crcannotations an where  an.filename != 'filename';
END //
DELIMITER ;

-- show create procedure RandomForestHCCResponse.CRCMutDependencies;
-- mysql  -re "call RandomForestHCCResponse.CRCMutDependencies();"| sed "s/NULL//g" >  datalocation/dependencies

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.CRCPyRadMatrix ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.CRCPyRadMatrix 
(  )
BEGIN
   -- select  a.mrn, a.TIMEID, sd.studyInstanceUID, lk.location,  
  select ca.mrn,ca.studydate ,cm.MutationalStatus, 
         concat_WS('/','/rsrch1/ip/dtfuentes/github/imagingsignature/ImageDatabase',ca.Image ) Image , 
         concat_WS('/','/rsrch1/ip/dtfuentes/github/imagingsignature/ImageDatabase',ca.Mask  ) Mask, 
         lk.labelID Label,
   from  RandomForestHCCResponse.crcannotations ca 
   join  RandomForestHCCResponse.crcmutations   cm   on ca.mrn=cm.mrn and ca.studydate=cm.ImageDate 
   join   RandomForestHCCResponse.liverLabelKey    lk on lk.labelID in (2,3,4);
END //
DELIMITER ;
-- mysql  -re "call RandomForestHCCResponse.PyRadiomicsMatrix ();"     | sed "s/\t/,/g;s/NULL//g" > datalocation/pyradiomics.csv
