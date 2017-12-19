##Save Niffty Image from simple numpy array (may need to add include more dicom tag to this file later)
from PIL import Image, ImageDraw
##IMPORT DICOM IMAGE
import numpy as np
import nibabel as nib  
  
image_size = (256,256)
# CREATE NEW ANNOTATION IMAGE (READ PILLOW PACKAGE)  
annotation_img = Image.new('L', image_size, 0)
# ADD DRAWING TOOL TO IMAGE
d = ImageDraw.Draw(annotation_img)
#DRAW CIRCLE
print("this is circle data given in center,radius")
cdata = [0.,0.,5.,5.]
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
#CONVER IMAGE TO NUMPY ARRAY AND MAKE ADJUSTMENT (TRANPOSE, FLIP IF NECCESSARY TO MATCH DICOME REFERENCE IMAGE)
im_array = np.array(annotation_img)
transpose = np.transpose(im_array)
#SAVE TO NIFTY USING nibabel PACKAGE
new_image = nib.Nifti1Image(transpose, affine=np.eye(4))
nib.save(new_image,'test.annotation.nii.gz')

