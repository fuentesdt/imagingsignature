#'   > source('driver.R')
options("width"=180)
args <- c( "datalocation/pyradiomicsout.csv","MutationalStatus")
params <- new.env(parent = baseenv())
params$csvPath         <-  args[1] 
params$target          <-  args[2] 
# TODO - FIXME - READ from cmd line ? 
params$inputs          <-  readRDS("./features.RDS")	
params$plot            <-  TRUE	
params$leaveOneOut     <-  TRUE	
params$rescale         <-  TRUE	
params$removeCorrelated<-  TRUE	
params$semisupervised  <-  FALSE	
params$kClusters       <-  as.numeric(9)	
params$genetic         <-  FALSE	
params$boruta          <-  TRUE	
params$univariate      <-  TRUE	
	
require(rmarkdown) 
rmarkdown::render( "datamatrixModeling_binary.RMD" ,params, "pdf_document", output_file = "myfile.pdf")
