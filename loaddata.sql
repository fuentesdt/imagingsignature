DROP TABLE IF EXISTS annotations;
CREATE TABLE annotations(
  filename         TEXT NOT NULL,
  niftypath         TEXT NOT NULL,
  ReferenceSOPUID         TEXT NOT NULL,
  StudyUID         TEXT NOT NULL,
  SeriesUID         TEXT NOT NULL,
  StudyDate         TEXT NOT NULL
);

.mode csv
.separator "\t"
.import datalocation/phiannotations.csv  annotations

select "ANNOTATIONS=" || group_concat(an.niftypath,' ') from annotations an where  an.filename != 'filename';
