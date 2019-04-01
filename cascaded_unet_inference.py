# coding: utf-8

# In this notebook, we do inference on abdomen CT slices using the cascade of 2 UNETs. First to segment the liver then segment liver lesions.
# 
# Requirements:
# - pip packages:
#   - scipy
#   - numpy
#   - matplotlib
#   - dicom
#   - natsort
# - A build of the Caffe branch at : https://github.com/mohamed-ezz/caffe/tree/jonlong
#   - This branch just merges Jon Long's branch : https://github.com/longjon/caffe/ with the class weighting feature by Olaf Ronnenberg (code at http://lmb.informatik.uni-freiburg.de/people/ronneber/u-net/).
#   - Class weighting feature is not needed for inference in this notebook, but we unify the caffe dependency for training and inference tasks.

# #### Download model weights and define the paths to the deploy prototxts####

# In[ ]:


# Get model weights (step1 and step2 models)
#get_ipython().system(u'wget --tries=2 -O ../models/cascadedfcn/step1/step1_weights.caffemodel https://www.dropbox.com/s/aoykiiuu669igxa/step1_weights.caffemodel?dl=1')
#get_ipython().system(u'wget --tries=2 -O ../models/cascadedfcn/step2/step2_weights.caffemodel https://www.dropbox.com/s/ql10c37d7ura23l/step2_weights.caffemodel?dl=1')


# In[ ]:


STEP1_DEPLOY_PROTOTXT = "./models/cascadedfcn/step1/step1_deploy.prototxt"
STEP1_MODEL_WEIGHTS   = "./models/cascadedfcn/step1/step1_weights.caffemodel"
STEP2_DEPLOY_PROTOTXT = "./models/cascadedfcn/step2/step2_deploy.prototxt"
STEP2_MODEL_WEIGHTS   = "./models/cascadedfcn/step2/step2_weights.caffemodel"


# In[ ]:



import nibabel as nib  
import numpy as np
#from matplotlib import pyplot as plt
#from IPython import display
#plt.set_cmap('gray')
#get_ipython().magic(u'matplotlib inline')
import scipy
import scipy.misc


IMG_DTYPE = np.float
SEG_DTYPE = np.uint8

import natsort
import os
import re

            
def stat(array):
    print 'min',np.min(array),'max',np.max(array),'median',np.median(array),'avg',np.mean(array)
def imshow(*args,**kwargs):
    """ Handy function to show multiple plots in on row, possibly with different cmaps and titles
    Usage: 
    imshow(img1, title="myPlot")
    imshow(img1,img2, title=['title1','title2'])
    imshow(img1,img2, cmap='hot')
    imshow(img1,img2,cmap=['gray','Blues']) """
    cmap = kwargs.get('cmap', 'gray')
    title= kwargs.get('title','')
    if len(args)==0:
        raise ValueError("No images given to imshow")
    elif len(args)==1:
        plt.title(title)
        plt.imshow(args[0], interpolation='none')
    else:
        n=len(args)
        if type(cmap)==str:
            cmap = [cmap]*n
        if type(title)==str:
            title= [title]*n
        plt.figure(figsize=(n*5,10))
        for i in range(n):
            plt.subplot(1,n,i+1)
            plt.title(title[i])
            plt.imshow(args[i], cmap[i])
    plt.show()
    
def to_scale(img, shape=None):

    height, width = shape
    if img.dtype == SEG_DTYPE:
        return scipy.misc.imresize(img,(height,width),interp="nearest").astype(SEG_DTYPE)
    elif img.dtype == IMG_DTYPE :
        max_ = np.max(img)
        factor = 255.0/max_ if max_ != 0 else 1
        return (scipy.misc.imresize(img,(height,width),interp="nearest")/factor).astype(IMG_DTYPE)
    elif  img.dtype == np.float32 :
        return scipy.misc.imresize(img,(height,width),interp="nearest",mode='F').astype(IMG_DTYPE)
    else:
        raise TypeError('Error. To scale the image array, its type must be np.uint8 or np.float64. (' + str(img.dtype) + ')')


def normalize_image(img):
    """ Normalize image values to [0,1] """
    min_, max_ = float(np.min(img)), float(np.max(img))
    return (img - min_) / (max_ - min_)


def histeq_processor(img):
        """Histogram equalization"""
        nbr_bins=256
        #get image histogram
        imhist,bins = np.histogram(img.flatten(),nbr_bins,normed=True)
        cdf = imhist.cumsum() #cumulative distribution function
        cdf = 255 * cdf / cdf[-1] #normalize
        #use linear interpolation of cdf to find new pixel values
        original_shape = img.shape
        img = np.interp(img.flatten(),bins[:-1],cdf)
        img=img/255.0
        return img.reshape(original_shape)

# ### Volume Preprocessing functions ### 

# In[ ]:



def preprocess_lbl_slice(lbl_slc):
    """ Preprocess ground truth slice to match output prediction of the network in terms 
    of size and orientation.
    
    Args:
        lbl_slc: raw label/ground-truth slice
    Return:
        Preprocessed label slice"""
    lbl_slc = lbl_slc.astype(SEG_DTYPE)
    #downscale the label slc for comparison with the prediction
    lbl_slc = to_scale(lbl_slc , (388, 388))
    return lbl_slc

def step1_preprocess_img_slice(img_slc):
    """
    Preprocesses the image 3d volumes by performing the following :
    1- Rotate the input volume so the the liver is on the left, spine is at the bottom of the image
    2- Set pixels with hounsfield value great than 1200, to zero.
    3- Clip all hounsfield values to the range [-100, 400]
    4- Normalize values to [0, 1]
    5- Rescale img and label slices to 388x388
    6- Pad img slices with 92 pixels on all sides (so total shape is 572x572)
    
    Args:
        img_slc: raw image slice
    Return:
        Preprocessed image slice
    """      
    img_slc   = img_slc.astype(IMG_DTYPE)
    img_slc[img_slc>1200] = 0
    img_slc   = np.clip(img_slc, -100, 400)    
    #if True:
    #    img_slc = histeq_processor(img_slc)
    img_slc   = normalize_image(img_slc)
    img_slc   = to_scale(img_slc, (388,388))
    img_slc   = np.pad(img_slc,((92,92),(92,92)),mode='reflect')

    return img_slc

def step2_preprocess_img_slice(img_p, step1_pred):
    """ Preprocess img slice using the prediction image from step1, by performing
    the following :
    1- Set non-liver pixels to 0
    2- Calculate liver bounding box
    3- Crop the liver patch in the input img
    4- Resize (usually upscale) the liver patch to the full network input size 388x388
    5- Pad image slice with 92 on all sides
    
    Args:
        img_p: Preprocessed image slice
        step1_pred: prediction image from step1
    Return: 
        The liver patch and the bounding box coordinate relative to the original img coordinates"""
    
    img = img_p[92:-92,92:-92]
    pred = step1_pred.astype(SEG_DTYPE)
    
    # Remove background !
    img = np.multiply(img,np.clip(pred,0,1))
    # get patch size
    col_maxes = np.max(pred, axis=0) # a row
    row_maxes = np.max(pred, axis=1)# a column

    nonzero_colmaxes = np.nonzero(col_maxes)[0]
    nonzero_rowmaxes = np.nonzero(row_maxes)[0]

    x1, x2 = nonzero_colmaxes[0], nonzero_colmaxes[-1]
    y1, y2 = nonzero_rowmaxes[0], nonzero_rowmaxes[-1]
    width = x2-x1
    height= y2-y1
    MIN_WIDTH = 60
    MIN_HEIGHT= 60
    x_pad = (MIN_WIDTH - width) / 2 if width < MIN_WIDTH else 0
    y_pad = (MIN_HEIGHT - height)/2 if height < MIN_HEIGHT else 0

    x1 = max(0, x1-x_pad)
    x2 = min(img.shape[1], x2+x_pad)
    y1 = max(0, y1-y_pad)
    y2 = min(img.shape[0], y2+y_pad)

    img = img[y1:y2+1, x1:x2+1]
    img = to_scale(img, (388,388))

    # Now do padding for UNET, which takes 572x572
    img=np.pad(img,92,mode='reflect')
    return img, (x1,x2,y1,y2)


# setup command line parser to control execution
from optparse import OptionParser
parser = OptionParser()
parser.add_option( "--imagefile",
                  action="store", dest="imagefile", default=None,
                  help="FILE containing image info", metavar="FILE")
parser.add_option( "--segmentation",
                  action="store", dest="segmentation", default=None,
                  help="OUTPUT Segmentation FILE ", metavar="FILE")
(options, args) = parser.parse_args()

if (options.imagefile != None):
  import caffe
  print caffe.__file__
  # Use CPU for inference
  #caffe.set_mode_cpu()
  # Use GPU for inference
  caffe.set_mode_gpu()

  # load nifti file
  imagedata = nib.load(options.imagefile)
  numpyimage= imagedata.get_data()

  # create empty segmentation
  segmentation = np.zeros(             imagedata.shape         , dtype=np.uint8)
  pred_step2   = np.zeros( (388,388,segmentation.shape[2])     , dtype=np.uint8)  # hard code unet expected dimensions

  # ### Load network prototxt and weights and perform prediction ###
  # #### Step 1 ####
  net1 = caffe.Net(STEP1_DEPLOY_PROTOTXT, STEP1_MODEL_WEIGHTS, caffe.TEST)
  print "%d slices: " % segmentation.shape[2]
  # loop through all slices
  for iii in range(segmentation.shape[2]):
  #for iii in [30]:
    print "%d  " % iii , 
    # NN expect liver in top left
    imageslice = numpyimage[...,iii]
    img_p = step1_preprocess_img_slice( imageslice.transpose() )
    #imshow(img_p,title=['Test image'])
    
    # Predict
    net1.blobs['data'].data[0,0,...] = img_p
    predprob = net1.forward()['prob'][0,1] 
    pred = predprob > 0.5
    #print pred.shape

    # save for step 2
    pred_step2[...,iii] = pred 
    
    # scale back to original size and store for step2
    imgtmp = to_scale(predprob, segmentation.shape[0:2])
    segmentation[...,iii] = imgtmp > 0.5

    # Visualize results
    #imshow(img_p[92:-92,92:-92], predprob, pred, title=['Slice%03d' % iii, 'probability', 'Prediction'])
    
    # end for

  # Free up memory of step1 network
  del net1
    
  # Load step2 network
  net2 = caffe.Net(STEP2_DEPLOY_PROTOTXT, STEP2_MODEL_WEIGHTS, caffe.TEST)
    
  print "\n step 2: " 
  # loop through all slices
  for iii in range(segmentation.shape[2]):
    print "%d  " % iii , 

    # retrieve stored liver mask prediction
    pred = pred_step2[...,iii] 

    # skip this slice if no mask
    if np.max(pred ):
      # NN expect liver in top left
      imageslice = numpyimage[...,iii]
      img_p = step1_preprocess_img_slice( imageslice.transpose() )

      # Prepare liver patch for step2
      # net1 output is used to determine the predicted liver bounding box
      img_p2, bbox = step2_preprocess_img_slice(img_p, pred)
      #imshow(img_p2)
      
      # Predict
      net2.blobs['data'].data[0,0,...] = img_p2
      pred2prob = net2.forward()['prob'][0,1]
      
      # Visualize result
      # extract liver portion as predicted by net1
      x1,x2,y1,y2 = bbox
      #imshow(img_p2[92:-92,92:-92], pred2prob>0.5,title=['Slice%03d' % iii, 'Prediction'])

      # paste tumor prediction back to slice
      pred2tmp = to_scale(pred2prob , (y2-y1+1,x2-x1+1) )
      pred2tmpstep1 = np.zeros( (388,388)   , dtype=np.float32)
      print y1, y2, x1, x2
      try:
        pred2tmpstep1[ y1:y2+1,x1:x2+1 ] = pred2tmp 
      except ValueError: # Hack boundary
        print "FIXME: boundary" 
        pred2tmpstep1[ y1:y2+1,x1-1:x2 ] = pred2tmp 

      # scale back to original size 
      imgtmp = to_scale(pred2tmpstep1, segmentation.shape[0:2])
      tumormask = imgtmp > 0.5

      # combine with liver mask
      livermask = segmentation[...,iii] 
      livertumormask = livermask + tumormask

      # (transpose back for write)
      segmentation[...,iii] = livertumormask.transpose() 

    # end for
  # Free up memory of step2 network
  del net2

  # save segmentation
  imgnii = nib.Nifti1Image(segmentation , imagedata.affine )
  imgnii.to_filename( options.segmentation )

else:
  parser.print_help()
  print options


