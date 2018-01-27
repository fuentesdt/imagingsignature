##note:  install pillow (not PIL but call it with import PIL), 

## THERE ARE 2 MAIN SECTION:
## (1)PARSE ANNOTATION FILE (annotation file is small and has dicom struture. usually have name starting with Sg, or PS when export from ISITE)
## (2)SAVE ANNOTATION INTO NIFTY (only convert simple image numpy array to nifty,e.g not include any dicom parameters at this stage)

import dicom
import numpy as np
from pprint import pprint
import os
import json



##Save Niffty Image from simple numpy array (may need to add include more dicom tag to this file later)
def process_graphdata(refimg,metastudy,sourcefids,graphdata,locol_imagesize,table_id):
  from PIL import Image, ImageDraw
  ##IMPORT DICOM IMAGE
  import dicom
  import numpy as np
  import nibabel as nib  
  
  has_data=False
  has_reference_image = False
  try: 
    #READ DICOM FILE TO GET IMAGE SIZE
    ds=dicom.read_file(refimg['fullpath'])
    rows = ds.Rows
    columns = ds.Columns
    ##set image size
    image_size = width, heigh = (rows,columns)
    print(image_size)
    has_reference_image = True
  except:
    image_size = width, heigh = locol_imagesize
    dbc.execute("UPDATE xfer_thomas.mrn_annotation SET note = 'no reference image' where id = %s", (table_id) )

  # CREATE NEW ANNOTATION IMAGE (READ PILLOW PACKAGE)  
  annotation_img = Image.new('L', image_size, 0)
  # ADD DRAWING TOOL TO IMAGE
  d = ImageDraw.Draw(annotation_img)
  # LOOP THROUGH ANNOTATION GRAPHIC DATA AND DRAW ONLY CIRCLE AND LINE, POLYLINE FOR NOW.
  for g in graphdata:
      #DRAW POLYLINE that has less than 5 connection
      if g['type']=="POLYLINE" and len(g['data']) <=10:
          cdata = g['data']
          print("this is polyline data, could be line")
          print (cdata)
          d.line(cdata, fill = 'white')
          has_data=True
      #DRAW CIRCLE
      elif g['type']=="CIRCLE":
          cdata = g['data']
          print("this is circle data given in center,radius")
          print (cdata)
          x1 = cdata[0]
          y1 = cdata[1]
          x2 = cdata[2]
          y2 = cdata[3]
          ## convert to ImageDraw box form; 
          r = ((x2-x1)**2 + (y2-y1)**2)**(1/2.0)
          #draw circle
          d.ellipse((x1-r,y1-r,x1+r,y1+r), fill = 'white', outline ='white')
          has_data=True
  #SAVE IMAGE TO NIFTY AND UPDAE DATABASE LOCATION
  if (has_data and has_reference_image):
    #CONVER IMAGE TO NUMPY ARRAY AND MAKE ADJUSTMENT (TRANPOSE, FLIP IF NECCESSARY TO MATCH DICOME REFERENCE IMAGE)
    im_array = np.array(annotation_img)
    transpose = np.transpose(im_array)
    #SAVE TO NIFTY USING nibabel PACKAGE
    new_image = nib.Nifti1Image(transpose, affine=np.eye(4))
    nib.save(new_image,refimg['fullpath']+'.annotation.nii.gz')

    #SAVE NIFTY LOCATION TO DATABASE
    dbc.execute('select * from external_files where study_id=%s and location=%s and path=%s',(metastudy,refimg['location'],refimg['path']+'.annotation.nii.gz'))
    if dbc.fetchone() is None:
       fid = dbc.insert("""insert into external_files (created_on, study_id, author_id, location, path, description, access_id, content_type, StudyUID, SeriesUID, StudyDate, StudyTime, SeriesDate, SeriesTime) 
                                                values (utcnow(),%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                         """, (metastudy,dbc.userid,refimg['location'],refimg['path']+'.annotation.nii.gz',refimg['path'].split('/')[-1]+'.annotation.nii.gz',4,5,
                               refimg['StudyUID'],refimg['SeriesUID'],refimg['StudyDate'],refimg['StudyTime'],refimg['SeriesDate'],refimg['SeriesTime']))
       dbc.execute('insert into external_meta_info (file_id, name, value, uname, time) values (%s,"annotation_source_file",%s,%s,utcnow())', (fid,sourcefids,dbc.user))
    
#SAVE ANNOTATION INTO NIFTY
if action == "save_annotation":  

  dbc.execute('use '+cf['mysql_meta_db'])
  dbc.execute("SELECT id, studyUID, annotations,fids FROM xfer_thomas.mrn_annotation where annotations like '%aq:%' or annotations like '%Art:%' group by studyUID, seriesUID")

  outp = dbc.fetchtodict()
  for res in outp:
    
    source_fids = res['fids']
    table_id = res['id']
    print
    print(source_fids)
    xstudyUID = res['studyUID']
    print(xstudyUID)
    annotations = json.loads(res['annotations'])
    ##pprint(annotations)  
    has_ref_image = False
    print("******")
  

    q = """select f.*,concat(l.parameters,'/',f.path) as fullpath
                   from external_files f
                   JOIN external_location l on f.location=l.id
                   where f.SOPUID = %s and study_id = 107 """
    for row in annotations:
      imageUID = row['RefernceImageUID']
      print("imageUID : "+ str(imageUID))
      graphdata = row['graphics']
      locol_imagesize = row['ImageSize']
      print(q%imageUID)
      dbc.execute(q,imageUID)
      try:
        res = dbc.fetchtodict()[0]
        #print(graphdata)
        #print(path)
        process_graphdata(res,107,source_fids,graphdata,locol_imagesize,table_id)
        has_ref_image = True
      except:
        has_ref_image = False
               
    if not (has_ref_image):
      dbc.execute("UPDATE xfer_thomas.mrn_annotation SET note = 'no reference image' where id = %s", (table_id) )  

#PARSE ANNOTATION FILE 
elif action == "parse_annotation": 
  annotation_creator = 'username_here'

  dbc.execute('use '+cf['mysql_meta_db'])
  ## SEARCH FOR ANNOTATION FILE LOCATION IN DATABASE
  q = """select f.id,concat(l.parameters,'/',f.path) as path
                   from external_files f
                   JOIN external_location l on f.location=l.id
                   where f.SeriesUID=%s and f.StudyUID=%s
                   and f.study_id=%s
                   """
  
  v=(form_dict.get('SeriesUID'),form_dict.get('StudyUID'),form_dict.get('metastudy'))
  ##query file location
  dbc.execute(q,v)
  files = dbc.fetchtodict()
  print
  print(q%v)
  ## out will be the extracted annotation output
  out=[]
  fids=[]
  allok=True
  ## LOOP THROUGH IMAGE FILE LOCATIONs AND READ IT
  for f in files:
      ## read individual image files and check if Modality = PR  (presentation state) to parse
      plan = dicom.read_file(f['path'])
      print(f['path'])
      try: 
        Modality = plan[(0x8, 0x60)].value
        print("modality is %s" % Modality)
        #IF ANNOTATION EXIST, THE MODALITY OF THE SERIES WILL BE NAMED 'PR'
        if not (Modality == 'PR'):
          print("skip ! since modality is not PR (not presentation stage)")
          continue
        #get annotation data of specify creator
        if not (plan[(0x8, 0x60)].value=='PR' and plan[(0x70, 0x84)].value==annotation_creator):
          print("the annotation creator is:");
          print(plan[(0x70, 0x84)].value)          
          print("Stop parsing annotation since the creator is not " + str(annotation_creator));
          continue
        fids.append(f['id'])
        print("this is fids")
        print(fids)
        print("*******")
        try:
           sq = plan[(0x70, 0x1)]
        except:
           print "Annotation squence (0x70,0x1) missing"
           sq = None
         
        if not sq is None:
          ##TRY TO PARSE THE FILE INTO "ReferenceImageUID, Text, and graphics) where text is annotation text, and graphic is annotation data 
          for s in sq:
              tmp={}
              try:
                tmp['RefernceImageUID']=s[(0x8, 0x1140)][0][(0x8, 0x1155)].value;
                ## get the 2nd sequence for image size. the first one usually scount image.
                tmp['ImageSize'] = plan[(0x70, 0x5a)][1][(0x70, 0x53)].value
              except:
                tmp['RefernceImageUID']=None;
                tmp['ImageSize']=None;

              try:
                tmp['text']=[{'text':x[(0x70, 0x6)].value,'BBoxTopLeft':x[(0x70, 0x10)].value,'BBoxTopLeft':x[(0x70, 0x11)].value} for x in s[(0x70, 0x8)]]
              except:
                tmp['text']=[]

              try:
                tmp['graphics']=[{'type':x[(0x70, 0x23)].value,'data':x[(0x70, 0x22)].value} for x in s[(0x70, 0x9)]]
              except:
                tmp['graphics']=[]
              out.append(tmp)
        else:
          pass
          ##print plan
      except:
        import StringIO,traceback
        output = StringIO.StringIO()
        traceback.print_exc(file=output) 
        print 'FAILED!'
        print output.getvalue()
        print
        print plan
        allok=False
        out.append({'RefernceImageUID':None,'status':'error parsing'})

  #ENTER ANNOTATION DATA INTO DATABASE
  if len(out)>0:

      q= 'select * from xfer_thomas.mrn_annotation where mrn=%s and studyDate=%s'
      v =(plan.PatientID,plan.StudyDate)
      print(q%v)
      dbc.execute(q,v)
      ent = dbc.fetchtodict()
      print("Number of records exist in db")
      print(len(ent))
      ##print(ent)
      db_fids = [e['fids'] for e in ent]
      print(db_fids)
      if len(ent)>0:
          ##loop through each row
          for e in ent:
            xferid=None
            ##do json.dumps(fids) (this is the one we just from the parsing) to compare with the exisitng one in db
            if e['fids']==json.dumps(fids) or e['fids'] is None:
               print("current fids table db")
               print(e['fids'])
               print("fids in parse")
               print(json.dumps(fids))
               xferid=e['id']
               print(xferid)
               print "updating entry id %s" % xferid
            else:
               if not json.dumps(fids) in db_fids:
                  xferid = dbc.insert("insert into xfer_thomas.mrn_annotation (mrn,  studyDate, accessionNumber) values (%s,%s,%s)",(e['mrn'],e['studyDate'],e['accessionNumber']) )
                  print "inserted entry id %s" % xferid
            if not xferid is None:  
              print("update current id")
              print(e['id'])
              dbc.execute('update xfer_thomas.mrn_annotation set studyUID=%s where id = %s', (plan.StudyInstanceUID,xferid) )
              dbc.execute('update xfer_thomas.mrn_annotation set seriesUID=%s where id = %s', (plan.SeriesInstanceUID,xferid) )
              dbc.execute('update xfer_thomas.mrn_annotation set annotations=%s where id = %s', (json.dumps(out),xferid) )
              dbc.execute('update xfer_thomas.mrn_annotation set fids=%s where id = %s', (json.dumps(fids),xferid) )
  assert allok

