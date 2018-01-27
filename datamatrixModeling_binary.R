#'   > source('datamatrixModeling_binary.R')
#' ---	
#' title: "Data Matrix Modeling"	
#' output: pdf_document	
#' params:	
#'   csvPath:  !r "datalocation/pyradiomicsout.csv"	
#'   target:   MutationalStatus	
#'   inputs:   !r readRDS("datalocation/features.RDS")	
#'   plot:              !r TRUE	
#'   leaveOneOut:       !r FALSE	
#'   rescale:           !r TRUE	
#'   removeCorrelated:  !r TRUE	
#'   semisupervised:    !r FALSE	
#'   kClusters:         !r as.numeric(9)	
#'   genetic:           !r FALSE	
#'   boruta:            !r TRUE	
#'   univariate:        !r TRUE	
#' ---	
#' ## Version: BINARY CLASSIFIER	
#' Updated 12/18/2017 by E. Gates. See readme on github	
#' 	
#' WIP: semi-supervised feature and genetic variable selection	
#' 	
#' WIP: custom model selection	
#' 	
#' WIP: Compare to null model for imbalanced datasets	
#' 	
#' BUG: preprocess crashes when trying too many image features	
#' 	
#' BUG: statement "No univariate significant values" not printing.	
#' 	
#' Compiled: `r format(Sys.time(), "%Y-%b-%d %H:%M:%S")` 	
#' 	
#' Target Variable: `r params$target`	
#' 	
#' Input File:      `r params$csvPath`	
#' 	
#' Target and inputs are column headings in csv file,	
#' everything else is ignored	
#' 	
#' 	
#' 	
rm(list=ls())
options("width"=180)

stopQuietly <- function(...)
  {
  blankMsg <- sprintf( "\r%s\r", paste( rep(" ", getOption( "width" ) - 1L ), collapse = " ") );
  stop( simpleError( blankMsg ) );
  } # stopQuietly()

args <- commandArgs( trailingOnly = TRUE )
args <- c( "datalocation/pyradiomicsout.csv","MutationalStatus")
	
if( length( args ) < 2 )
  {
  cat( "Usage: Rscript datamatrixModeling_binary.R inputFileList outputModelPrefix ",
       "<numberOfThreads=4> <trainingPortion=1.0> <numberOfSamplesPerLabel=1000> ",
       "<numberOfTreesPerThread=1000> <numberOfUniqueLabels=NA>", sep = "" )
  stopQuietly()
  }
params <- new.env(parent = baseenv())

params$csvPath         <-  args[1] 
params$target          <-  args[2] 
# TODO - FIXME - READ from cmd line ? 
params$inputs          <-  readRDS("./features.RDS")	
params$plot            <-  TRUE	
params$leaveOneOut     <-  FALSE	
params$rescale         <-  TRUE	
params$removeCorrelated<-  TRUE	
params$semisupervised  <-  FALSE	
params$kClusters       <-  as.numeric(9)	
params$genetic         <-  FALSE	
params$boruta          <-  TRUE	
params$univariate      <-  TRUE	
	
	
# install.packages("caret",repos='http://cran.us.r-project.org')
# install.packages("knitr",repos='http://cran.us.r-project.org')
# install.packages("e1071",repos='http://cran.us.r-project.org')
# install.packages("randomForest",repos='http://cran.us.r-project.org')
# install.packages("xgboost",repos='http://cran.us.r-project.org')
# install.packages(c("leaps","corrplot","gridExtra","pROC","subselect"),repos='http://cran.us.r-project.org')
libs <- c("caret", "kernlab", "knitr", "e1071", "magrittr", "rpart", "nnet", "parallel",	
"randomForest", "xgboost", "Boruta", "leaps", "MASS",	
"ranger", "cluster", "subselect", "corrplot", "gridExtra","pROC")	
	
lapply(libs, require,character.only=T)
set.seed(25)	
	
#Load data	
datamatrixfull <- read.csv(params$csvPath, na.strings = "NULL")	
datamatrix <- subset(datamatrixfull,MutationalStatus != "Experimental cohort")
datamatrix$MutationalStatus  =  droplevels(datamatrix$MutationalStatus ) 

if(is.null(params$inputs)){	
  print("No input columns specified, using all non-target columns")	
  params$inputs <- setdiff(names(datamatrix),params$target)	
} 	
	
#error check	
if(is.null(params$target)) stop("No target specified")	
	
# Set model parameters	
modelparams <- list(tree = list(method  = "rpart",	
                    #            #tuneGrid = data.frame(.cp = 0.01),	
                                 parms   = list(split="information")	
                               ),	
                                          	
                    forest = list(method      = "rf",	
                                  ntree       = 500,	
                                 #tuneGrid    = data.frame(.mtry = mtry),	
                                 #replace    = TRUE,	
                                 #na.action  = randomForest::na.roughfix,	
                                 importance  = FALSE,	
                                 predict.all = FALSE	
                                 ),	
                     #na.action removed since "na.action" is used in caret	
                    	
                     xgboost = list(method = "xgbLinear"),	
 	
                     nnet = list(method = "nnet",	
                                 #tuneGrid=data.frame(.size = 10, .decay = 0),	
                                 #linout  = TRUE,	
                                 skip    = TRUE,	
                                 MaxNWts = 10000,	
                                 trace   = FALSE,	
                                 maxit   = 100),	
                     	
                     svm = list(method = "svmRadial"),	
                     logit = list(method = "glm")	
)	
	
# Partition + Trim dataset for convenience	
dsraw <- datamatrix[ c(params$target, params$inputs) ]	
	
#set.seed(5)	
#inTrain <- createDataPartition(as.factor(datamatrix[,params$target]), 1, p=0.7)	
#  testing <- dsraw[-inTrain[[1]], ]	
#  dsraw <- dsraw[inTrain[[1]], ]	
	
	
	
	
	
#' 	
#' ## Pre-processing data: By default removes columns with zero variance and discards variables correlated >0.8	
#' 	
#  methods: zv removes zero-variance columns	
#           corr removes highly correlated columns	
#           center/scale recenters variables	
	
	
#coerce to factor if needed	
if(!is.factor(dsraw[params$target])){	
  dsraw[params$target]<- as.factor(dsraw[,params$target])	
  levels(dsraw[,params$target])<- c("control","case")	
}	
	
#check if binary	
if(dsraw[,params$target] %>% levels %>% length !=2){	
    stop("Target must have two levels")	
}   	
	
#remove columns where all values are NA	
# REMOVE ROWS WITH NA	
dsraw <- dsraw[complete.cases(dsraw),colSums(is.na(dsraw))<nrow(dsraw)]	
	
#reduced input set	
inputs <- setdiff(names(dsraw),params$target)	
	
ppMethods <- "zv"	
if(params$rescale)          {ppMethods <- c(ppMethods,"center","scale")}	
if(params$removeCorrelated) {ppMethods <- c(ppMethods, "corr")}	
	
#first remove zero variance (caret bug workaround)	
pp <- preProcess(dsraw[inputs], method = "zv")	
ds <- cbind(predict(pp, newdata = dsraw[inputs]),dsraw[params$target])	
Filteredinputs <- setdiff(names(ds), params$target)	
	
pp <- preProcess(predict(pp, newdata = ds[Filteredinputs]), method = ppMethods, cutoff=0.8)	
	
#get reduced input set/dataset	
ds <- cbind(predict(pp, newdata = ds[Filteredinputs]),ds[params$target])	
Filteredinputs <- setdiff(names(ds), params$target)	
	
	
# WIP: Clustering for semi-supervised analysis with kClusters	
if(params$semisupervised){	
cat(paste("Clustering into ", params$kClusters, " clusters... By unsupervised random forest\n\n"))	
rfUL <- randomForest(x=ds[,Filteredinputs],	
                     ntree = 500,	
                     replace=FALSE)	
ds <- cbind(ds, clusters.conv = pam(1-rfUL$proximity, k = params$kClusters, diss = TRUE, cluster.only = TRUE))	
ds$clusters.conv <- as.factor(ds$clusters.conv) #change to factor not int	
Filteredinputs <- setdiff(names(ds),params$target)	
}	
	
#' 	
#' 	
#' ## Pre-Processing results: 	
#' Started with `r length(inputs)` non-NA variables.	
#' 	
pp	
#' 	
#' `r length(Filteredinputs)` remained after pre-processing	
#' 	
#' ## Variable Selection: 	
#' 	
#' Default is Boruta and Wilcoxon test (P value cutoff 0.20/ `r length(Filteredinputs)`). Wilcoxon currently only tests numeric input variables	
#' 	
#' 	
	
# Variable selection 	
variableSelections <- list() #list(all=Filteredinputs)	
	
#if <30 variables use all of them	
if(Filteredinputs %>% length <= 30){	
  variableSelections[["all"]] <- Filteredinputs	
	
  correlations <- cor(Filter(is.numeric,ds[variableSelections$all]), use="pairwise")	
   corrord <- order(correlations[1,])	
   correlations <- correlations[corrord,corrord]	
   corrplot(correlations,	
   title = "Correlations for all variables",	
   mar = c(1,2,2,0)  )	
  }	
	
#genetic	
if(params$genetic){	
gen <- genetic(cor(ds[,Filteredinputs]), 4) #manually selected 4 outputs	
variableSelections$genetic <- names(ds[,Filteredinputs])[gen$bestsets]	
print("Genetic variable selections:")	
print(variableSelections$genetic)	
	
correlations <- cor(Filter(is.numeric,ds[variableSelections$genetic]), use="pairwise")	
   corrord <- order(correlations[1,])	
   correlations <- correlations[corrord,corrord]	
   corrplot(correlations,	
   title = "Correlations for Genetic method",	
   mar = c(1,2,2,0)  )	
	
}	
	
#boruta	
if(params$boruta){	
bor <- Boruta(x=ds[,Filteredinputs], y=ds[,params$target], maxRuns = 500)	
variableSelections$boruta <- names(ds[,Filteredinputs])[which(bor$finalDecision == "Confirmed")]	
	
print("Finished Boruta variable selection")	
print(bor)	
	
	
if(length(variableSelections$boruta) > 0 & params$plot){	
	
correlations <- cor(Filter(is.numeric,ds[variableSelections$boruta]), use="pairwise")	
   corrord <- order(correlations[1,])	
   correlations <- correlations[corrord,corrord]	
   corrplot(correlations,	
   title = "Correlations for Boruta method",	
   mar = c(1,2,2,0)  )	
	
	
#par(mfrow=c(length(variableSelections$boruta),1))	
for(iii in 1:length(variableSelections$boruta)){	
boxplot( as.formula( paste(variableSelections$boruta[[iii]], "~", params$target) ),	
         data=ds,	
         ylab=paste(variableSelections$boruta[[iii]]),	
         mar=c(12,1,0,0)	
       )	
}# end boxplots	
} #end if >0 variables	
} #end if params$boruta	
	
	
#univariate (currently only works for numeric variables)	
if(params$univariate){	
	
nums <- sapply(ds[Filteredinputs],is.numeric)	
nums <- names(nums)[nums] #get names not T/F	
pvals <- lapply(nums,	
       function(var) {          	
           formula    <- as.formula(paste(var, "~", params$target))	
           test <- wilcox.test(formula, ds[, c(var, params$target)])	
           test$p.value #could use 1-pchisq(test$statistic, df= test$parameter)	
       })	
	
	
	
#pvals <- lapply(nums,	
#      function(var) {	
#        formula    <- as.formula(paste(params$target, "~", var))	
#           logit <- glm(formula, data=ds[, c(var,params$target)], family=binomial )	
#           coef(summary(logit))[2,4]	
#      })	
	
	
variableSelections$univariate <- setdiff(Filteredinputs, nums[pvals > 0.2/length(nums)]) #discard variables above threshold	
	
if(variableSelections$univariate %>% length > 1 & params$plot){	
correlations <- cor(Filter(is.numeric,ds[variableSelections$univariate]), use="pairwise")	
   corrord <- order(correlations[1,])	
   correlations <- correlations[corrord,corrord]	
   corrplot(correlations,	
   title = "Correlations for Univariate method",	
   mar = c(1,2,2,0)  )	
   	
	
#par(mfrow=c(length(variableSelections$univariate),1))	
for(iii in 1:length(variableSelections$univariate)){	
boxplot( as.formula( paste(variableSelections$univariate[[iii]], "~", params$target) ),	
         data=ds,	
         ylab=paste(variableSelections$univariate[[iii]]),	
         mar=c(12,1,0,0)	
       )	
}# end boxplots	
}	
}	
#' 	
#' 	
#' 	
#' 	
	
#print results and error handle if no significant variables	
if(params$univariate){	
  if(length(variableSelections$univariate) == 0){ 	
    sprintf("No P values < %.5f", 0.2/length(nums))	
    variableSelections$univariate <- NULL	
    } else {	
      pvaltable <- data.frame(Variable = Filteredinputs[pvals< (0.2/length(nums)) ],	
                        P_value = unlist(pvals[pvals<(0.2/length(nums))] )	
                        )	
      kable(pvaltable, format = "markdown")	
    }	
}	
#' 	
#' 	
#' 	
#' 	
#' 	
#' # Modeling using `r names(modelparams)`.	
#' Use Leave-one-out cross validation: `r params$leaveOneOut`	
#' 	
#' 	
#' 	
	
#WIP: consider using metric=roc for binary classification	
	
#Modeling, dataparams are arguements to caret::train	
modelformula <- as.formula(paste(params$target,"~."))	
dataparams   <- list(form = modelformula,	
#                      data = ds[,c(params$target,Filteredinputs)],	
                      metric="Accuracy", #other option: AUC?	
                      trControl=trainControl(allowParallel  = T,	
                                             method = ifelse(params$leaveOneOut,"LOOCV", "repeatedcv"),	
                                             classProbs=TRUE,	
                                             #returnResamp = "final",	
                                             #number = 10,	
                                             #repeats= 5,	
                                             verboseIter = F) # use method="none" to disable grid tuning for speed	
                     )  	
caretparams      <- lapply(modelparams,function(x) c(dataparams,x))	
	
#initialize outputs	
models    <- list()	
acc <- list()	
	
for(jjj in 1:length(variableSelections)){	
modeldata  <- ds[,c(params$target,variableSelections[[jjj]])]	
	
# RE seeding: Hawthorn et al, "The design and analysis of benchmark experiments" (2005)	
	
for (iii in 1:length(modelparams)){	
model_name <-paste(names(variableSelections)[jjj], names(modelparams)[iii],sep="_")	
#print(paste("Training model", iii, "of", (length(modelparams)*length(variableSelections)), ":", model_name, sep=" "))	
set.seed(3141) #seed before train to get same subsamples	
invisible(  models[[model_name]] <- do.call(caret::train, c(caretparams[[iii]], list(data=modeldata)))  )	
	
metric <- models[[model_name]]$metric	
	
#get best acuracy manually for LOOCV	
acc[[model_name]] <- max(models[[model_name]]$results[metric])	
	
}	
	
	
}	
	
	
#' 	
#' 	
#' 	
#' 	
if(params$leaveOneOut){	
  maxacc <- max(unlist(acc))	
  maxmodels <- names(which(acc==maxacc))	
	
  #plot	
  par(mar=c(8,5,1,1))	
  barplot(unlist(acc),las=2, ylim=c(0,1),	
    ylab=paste("training set LOOCV",metric))	
  	
} else {	
  rs <- resamples(models)	
  print(summary(object = rs))	
  	
  acc        <- rs$values[,grepl(rs$metrics[1], names(rs$values))]	
  names(acc) <- rs$models	
  maxacc <- max(apply(acc,2,mean))	
  maxmodels <- rs$models[apply(acc,2,mean)==maxacc]	
  	
  # plot +1 to col arg keeps one box from being black	
  par(mar=c(8,5,1,1))	
  boxplot(acc,col=(as.numeric(as.factor(rs$methods))+1), las=2,	
    ylab=paste("training set cross-validation",metric) )	
  legend("bottomright", legend=unique(rs$methods),	
    fill=(as.numeric(as.factor(rs$methods))+1) )	
}	
	
#get best accuracy	
#cat(paste("best model(s): ", maxmodels, "\n"))	
#cat(sprintf("%s: %.4f \n", metric, maxacc))	
#lapply(maxmodels, function(x) models[[x]])	
#' 	
#' 	
#' Best model(s): `r maxmodels`	
#' 	
#' `r sprintf("%s: %.4f", metric, maxacc)`	
#' 	
#' 	
lapply(maxmodels, function(x) models[[x]])	
#' 	
#' 	
#' 	
if(params$leaveOneOut){	
  print(paste("Building ROC Curve for model", maxmodels[[1]]))	
  #recursiely subset	
  bestmod <- models[[maxmodels[[1]]]] #pick first by default	
  modpars <- bestmod$bestTune	
  results <- bestmod$pred	
  	
  #filter predictions on best model	
  for(kkk in 1:length(modpars)){	
    results <- subset(results, results[,names(modpars)[kkk]]==modpars[,kkk])	
  }	
  	
  print(caret::confusionMatrix(results$pred, reference = results$obs, positive="case"))	
  ROC1 <- roc(response=results$obs, predictor = results$case)	
  print(ROC1)	
  plot(ROC1, print.auc=T, print.auc.y = 0.2, print.auc.x = 0.5)	
  # results is a frame with LOOCV data	
  	
  #best threshold based on sum of sens/spec	
  kable(coords(roc=ROC1, x = "best", ret=c('threshold','sens', 'spec')))	
  	
}	
