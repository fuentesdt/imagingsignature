SELECT aq.mrn, e.MutationalStatus,aq.StudyDate,aq.StudyUID, aq.seriesUID, aq.acquisitionTime  FROM student_intern.aq_sop aq
SELECT * FROM student_intern.aq_sop aq
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
on aq.mrn = e.MRN and e.`Im. Accession No.` = aq.AccessionNumber and e.Series = aq.seriesNo and e.`Images (art; pv)` = aq.imageNo ;
 


SELECT concat_WS('/','/FUS4/IPVL_research',aq.MRN,REPLACE(aq.StudyDate, '-', ''),aq.StudyUID,aq.SeriesUID) dcmpath, aq.SOP FROM student_intern.aq_sop aq
LEFT JOIN
(
SELECT uploadID,
JSON_UNQUOTE(data->"$.""MRN""") "MRN",
JSON_UNQUOTE(data->"$.""Image Date""") "Image Date",
JSON_UNQUOTE(data->"$.""Im. Accession No.""") "Im. Accession No.",
JSON_UNQUOTE(data->"$.""Mutational status""") "Mutational status",
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
on aq.mrn = e.MRN and e.`Im. Accession No.` = aq.AccessionNumber and e.Series = aq.seriesNo and e.`Images (art; pv)` = aq.imageNo;
