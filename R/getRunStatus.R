#' getRunStatus
#'
#' Returns the current status of a run or a vector of runs
#'
#' @param dir Path to the folder(s) where the run(s) is(are) performed
#' @param sort how to sort (nf=newest first)
#' @param onlyrunning show only currently running runs
#'
#'
#' @author Anastasis Giannousakis
#' @importFrom gdx readGDX
#' @importFrom utils tail
#' @export
getRunStatus<-function(dir=".",sort="nf",onlyrunning=FALSE){
  
  substrRight <- function(x, n){
    substr(x, nchar(x)-n+1, nchar(x))
  }
  
  onCluster <- file.exists("/p")
  out<-data.frame()
  
  a <- file.info(dir)
  a <- a[a[,"isdir"]==TRUE,]
  if (sort=="nf") dir <- rownames(a[order(a[,"mtime"],decreasing = T),])
  
  for (i in dir) {
    
    if (onCluster) out[i,"jobInSLURM"] <- foundInSlurm(i)
    
    if (onCluster) if (!out[i,"jobInSLURM"] & onlyrunning) {
     out <- out[setdiff(rownames(out),i),]
     next
    }
    
    cfgf <- paste0(i,"/config.Rdata")
    fle <- paste0(i,"/runstatistics.rda")
    gdx <- paste0(i,"/fulldata.gdx")
    fulllst <- paste0(i,"/full.lst")
    fulllog <- paste0(i,"/full.log")
    
    stats <- NULL
    runtype <- NULL
    
    # RunType
    if (file.exists(cfgf)) {
      load(cfgf)
#      if(any(grepl("config",names(stats)))) {
        out[i,"RunType"] <- cfg[["gms"]][["optimization"]]
        if (cfg[["gms"]][["CES_parameters"]]=="calibrate") out[i,"RunType"]<-paste0("Calib_",out[i,"RunType"])
        totNoOfIter <- cfg[["gms"]][["cm_iteration_max"]]
      } else if (file.exists(fulllst)) {
        out[i,"RunType"] <- sub("         !! def = nash","",sub("^ .*.ion  ","",system(paste0("grep 'setGlobal optimization  ' ",fulllst),intern=TRUE)))
        chck <- sub("       !! def = load","",sub("^ .*.ers  ","",system(paste0("grep 'setglobal CES_parameters  ' ",fulllst),intern=TRUE)))
        if (chck=="calibrate") out[i,"RunType"]<-paste0("Calib_",out[i,"RunType"])
      }
      
    # modelstat
    if (file.exists(fle)) {
      load(fle)
      if(any(grepl("modelstat",names(stats)))) out[i,"modelstat"] <- stats[["modelstat"]]
    } else {
      if (file.exists(gdx)) out[i,"modelstat"] <- as.numeric(readGDX(gdx,"o_modelstat", format="first_found"))
    }
    
    # Iter
    if (file.exists(fulllog)) {
      suppressWarnings(try(loop <- sub("^.*.= ","",system(paste0("grep 'LOOPS' ",fulllog," | tail -1"),intern=TRUE)),silent = TRUE))
      if (length(loop)>0) out[i,"Iter"] <- loop
      if (!out[i,"RunType"]%in%c("nash","Calib_nash") & length(totNoOfIter)>0) out[i,"Iter"] <- paste0(out[i,"Iter"],"/",sub(";","",sub("^.*.= ","",totNoOfIter)))
    } else {
      out[i,"Iter"] <- "NA"
    }
    
    # Conv  
    if (file.exists(fulllst)) {      if (length(out[i,"RunType"])>0)
      
      if (grepl("nash",out[i,"RunType"]) & !is.na(out[i,"RunType"])) {
        
        totNoOfIter <- tail(system(paste0("grep 'cm_iteration_max = [1-9].*.;$' ",fulllst),intern=TRUE),n=1)
        if (length(totNoOfIter)>0) out[i,"Iter"] <- paste0(out[i,"Iter"],"/",sub(";","",sub("^.*.= ","",totNoOfIter)))
        
        if (length(system(paste0("grep 'Convergence threshold' ",fulllst),intern=TRUE))>1) {
          out[i,"Conv"] <- "converged"
        } else if (length(system(paste0("grep 'Nash did NOT' ",fulllst),intern=TRUE))>1) {
          out[i,"Conv"] <- "not_converged"
        } else {
#          iters <- suppressWarnings(system(paste0("grep -A 15 'PARAMETER p80_repy  sum' ",fulllst),intern=TRUE))
#          iters <- grep("^$|--|modelstat",iters,invert = TRUE,value=TRUE)
#          iters <- gsub("7","2",iters)
#          out[i,"Conv"]<-substrRight(paste(as.numeric(sub("critical solver status for solution","",sub("^.*.=","",iters))),collapse=""),10)
        }
      } else {
        out[i,"Conv"] <- "NA"
      }
      
    }
    
  }
  
  return(out)

}
