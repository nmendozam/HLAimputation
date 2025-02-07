#!/usr/bin/env Rscript

##############################################
# Combine imputation results (RDATA)
# author: Frauke Degenhardt
# contact: f.degenhardt@ikmb.uni-kiel.de
# April 2020
##############################################

################################
# Settings
################################
args = commandArgs(trailingOnly=T)

library("reshape2")
library("parallel")

print(args)
################################
# FUNCTIONS
################################

to.dosage = function(x, maj){
  miss = x=="00";  
  x=gsub(maj,"",x); 
  x=sapply(x,nchar);
  x[miss]=NA
  
  return(x)
}

convert = function(data){
  data$id = gsub(":.*","", data$id)
  data[data$ALT=="A",-(1:8)] = 2-   data[data$ALT=="A",-(1:8)]
  data[data$ALT=="A",c("ALT","REF")] =  data[data$ALT=="A",c("REF","ALT")]
  info = unique(data[,1:8])
  no = table(data$id)
  #no = no[no > 1]
  
  data = split(data,data$id)
  data = lapply(data, function(x){colSums(x[,-(1:8)])})
  data = do.call(rbind,data)
  data = cbind(info[match(rownames(data),info$id),], data)
  data = data[data$id%in%names(no),]
  return(data)
}



assign.HLA=function(data, fam, position){
  
  
  data[data$postprob < 0,c("A.name","B.name")] =NA
  data = melt(data[,c("id","locus", "A.name","B.name")],id=c("id","locus"))
  
  dos=c()
  
  for(i in unique(data$locus)){
    tmp = data[data$locus==i,]
    
    tmp$value=factor(tmp$value)
    tmp= as.data.frame.matrix(table(tmp$value, tmp$id))
    tmp[,colSums(tmp)==0]=NA
    dos=rbind(dos,tmp)
  }
  dos = dos[,match(fam$IID,colnames(dos))]

  position$mid = position$start+ceiling((position$end -position$start+1)/2)
  
  out = cbind(chr=6, id=paste0("imputed_HLA_", rownames(dos)),
                   pos=position[match(gsub("\\*.*","",rownames(dos)),position$locus),"mid"],
                   REF="A",ALT="P",dos)
  
  
  return(out)
}
# GET SNP/AA from HLA data
assign.SNP.PROT_prepare=function(data, info, fam, type){   
  
  data[data$postprob < 0,c("A.name","B.name")] =NA
  id = unique(data$id)
  
  out = mclapply(as.list(id),function(x){
    all = data[data$id==x,c("locus","A","B")]
     out= c()
    for(i in 1:nrow(all)){
      locus=all[i,"locus"]
      if(locus%in%c("DRB1","DRB3","DRB4","DRB5")){
        lib_loc = "DRB"
      }else{
        lib_loc=locus
      }
      gen = paste(locus,"*",as.character(all[i,c("A","B")]),sep="")
      gen = gsub("G", "", gen)
      lib = info[[paste(lib_loc,"_",type,sep="")]]
      colnames(lib)=paste(locus,"_",colnames(lib),sep="")
      rownames(lib)=gsub("[NLQEG]$","", rownames(lib)) # Only because gsubed in source

      if(any(!gen%in%rownames(lib))){
        tmp = lib
        if(!gen[1]%in%rownames(tmp)){
          tmp= rbind(tmp, rep(0, ncol(tmp)))
          rownames(tmp)[nrow(tmp)] = gen[1]
          print(paste(x, "Missing", gen[1]))
        }
        if(!gen[2]%in%rownames(tmp)){
          tmp= rbind(tmp, rep(0, ncol(tmp)))
          rownames(tmp)[nrow(tmp)] = gen[2]
           print(paste(x, "Missing", gen[2]))
        }
       # print(paste(x, "Missing", gen))

        out = cbind(out, as.matrix(tmp[gen,]))
      }else{
        out = cbind(out, as.matrix(lib[gen,]))
      }  }
    
    out = apply(out,2,function(x){x=toupper(x);
    if(type=="nuc"){
      x=sort(x);
    }
    x=paste(x,collapse="")
    x[grep("0",x)]="00"
    
    return(x)})
    return(out)}, mc.cores=detectCores(), mc.preschedule=F, mc.silent=F)
  
  out = do.call(rbind,out)

  if(type=="nuc"){
    out = out[,order(as.numeric(gsub(".*_|I","",colnames(out))))]
    out=  out[,as.numeric(gsub(".*_|I","",colnames(out)))>=25*10^6]  
  }
  
  out  = t(out)
  colnames(out) = id
  
  out = out[,match(fam$IID, colnames(out))]  
  out = cbind(rownames(out),rownames(out),out)
  out[,1] = paste0("imputed_",type,"_", out[,1])

  return(out)
 
}

assign.SNP.PROT=function(tmp){   
  # MAKE TO DOSAGE
  row.names=tmp[,1]
  
  tmp = tmp[,-(1:2)]
#  print(head(tmp)[,1:10])
  ###################################
  # Get the major and minor allele
  ##################################
  maj=apply(tmp,1,function(x){
    if(any(nchar(x)>2)){#Set InDels to missing
      return(c(NA,NA))
    }
        
    x=(unlist(strsplit(x,""))); 
    
    x[x==0]=NA; 
    x=(sort(table(x), decreasing=T))
    x=names(x)
    if(length(x)==0){ #If monomorphic set 0
              return(c("0","0"))
    }
    if(length(x)==1){ #If monomorphic set 0
      return(c(x,"0"))
    }
    if(length(x)==2){ #If biallelic return both alleles sorted
      return(x)
    }
    if(length(x)>2){ #If multiallelic return each allele separately
      paste(x,"")
      return(sapply(1:length(x),function(i) c(x[i],paste(x[-i],collapse = "or"))))
  #    return(c(NA,NA))
  }}) 
  if(is.list(maj)){
    nvariants = sapply(maj,function(x) if(is.vector(x)){1}else{ncol(x)})
    row.names = rep(row.names, times=nvariants)
    maj=matrix(unlist(maj),ncol=2,byrow = T)
    tmp = tmp[rep(1:nrow(tmp),times=nvariants),]
    row.names = paste(row.names,maj[,1],maj[,2],sep="_")
  } else {
    warning('unexpected old pathway. To reuse change line:  res = c(6,x[1],gsub(".*_([-0-9]+)_.*", "\\1",x[1]),al,to.dosage(x[-1],al[1]))')
#    nvariants = rep(1,ncol(maj))
#    maj=t(maj)
  }
  
  rownames(maj) =row.names
  
  ##################################
  # Calculate dosage on minor allele
  #################################
  
  data = apply(cbind(row.names,tmp),1,function(x){
    al = maj[x[1], ]

    res = c()
    if(!is.na(al[1]) & al[1]!="0"){
      if(grepl("prot",x[1])){
        protpos = gsub(".*_([-0-9]+)_.*", "\\1",x[1])
        locus=gsub(".*_([A-Z1-9]+)_[-0-9]+_.*", "\\1",x[1])
        nuc_pos = prot_pos(protpos,locus,prot,nuc2dig)
        res = c(6,x[1],nuc_pos,al,to.dosage(x[-1],al[1]))
      } else {
        res = c(6,x[1],gsub(".*_([-0-9]+)_.*", "\\1",x[1]),al,to.dosage(x[-1],al[1]))
      }
      return(res)
    }else{
      return(NULL)
    }
  }  
  )
  if(is.list(data)){
    data = do.call(rbind,data)
  } else{
    data= t(data)
  }
  colnames(data)[1:5] = c("chr","id","pos","REF","ALT")

  #switch ref and alt allele in multiallelic sites so dosages sum up to 2
  orAllelesREF = data[grepl("or",data[,"ALT"]),]
  orAllelesREF[,"REF"] = "A"
  orAllelesREF[,"ALT"] = "P" #orAllelesREF[,c("ALT","REF")]
  orAllelesREF[,-(1:5)] = 2- as.numeric(orAllelesREF[,-(1:5)])
  data[grepl("or",data[,"ALT"]),] = orAllelesREF
  return(data)
} 

translate= function(ALT, REF, dos){
  dos[dos==2] = paste0(REF, REF)
  dos[dos==1] = paste0(ALT, REF)
  dos[dos==0] = paste0(ALT, ALT)
  dos[is.na(dos)]=paste0("00")
  return(dos)
}

format_to_plink = function(fam, data){
  tr = apply(data, 1, function(x){
    translate(x[4], x[5], x[-(1:8)])
  })
  ped = cbind(fam, tr[match(rownames(tr),fam$IID),])
  map = cbind(data[,c(1,2)], 0, data[,3])
  map[,2] = gsub("\\*|:","_", map[,2])
  return(list(ped=ped, map=map))
}

prot_pos = function(protpos, locus,prot,nuc2dig){
  locus = gsub("DRB[1345]","DRB",locus)
  if((as.numeric(protpos)>=227 & locus == "DQB1") | (as.numeric(protpos)>=235 & locus == "DRB")){#positions not included in nuc reference
    return("0")
    }else{
    strand = data.frame(locus = c("A","B","C","DPA1","DPB1","DQA1","DQB1","DRB1"), strand=c("+","-","-","-","+","+","-","-"))
    pos_translation = if(strand$strand[grepl(paste0("^",locus),strand$locus)]=="+"){
      data.frame(POS = colnames(prot[[paste0(locus,"_prot")]]), BP = colnames(nuc2dig[[paste0(locus,"_nuc")]])[seq(1,ncol(nuc2dig[[paste0(locus,"_nuc")]])-3,3)])
    }else{
      data.frame(POS = colnames(prot[[paste0(locus,"_prot")]])[1:min(ncol(prot[[paste0(locus,"_prot")]]),ceiling(ncol(nuc2dig[[paste0(locus,"_nuc")]])/3))], 
                 BP = colnames(nuc2dig[[paste0(locus,"_nuc")]])[seq(1,min(ncol(prot[[paste0(locus,"_prot")]]),ceiling(ncol(nuc2dig[[paste0(locus,"_nuc")]])/3))*3,3)])}
    return(as.character(pos_translation$BP[pos_translation$POS==protpos]))
    
  }
}

################################
# MAIN
################################


args = commandArgs(T)
files  = args[1:(length(args)-3)]

files = sort(files)
output = list()
for (f in files){
  load(f)
  locus = gsub(".*_(.*).RData","\\1",f)
  output[[locus]] = pred
}
pred = output

args = tail(args,4)

## CONCATENATE GENE LOCIS

data = lapply(pred, function(x){x$value})
data = cbind(rep(names(pred), times = unlist(lapply(data, nrow))), do.call(rbind, data))
data = data.frame(data)
colnames(data)=c("locus","id","A","B","postprob")

## MATCH RDATA AND FAM FILE
fam= read.table(paste0(args[2],".fam"), h=F, col.names = c("FID","IID","","","","PHENO"))

# ASSIGN CORRECT ALLELE NAMES
data$A.name= paste(data$locus,data$A,sep="*")
data$B.name= paste(data$locus,data$B,sep="*")

# CONVERT TO DOSAGE INFORMATION
position=read.table(args[3],h=T)

out = assign.HLA(data, fam, position)
HLA = rbind(out, convert(out))

save = out
# REDUCE TO 2 FIELD ANNOTATION
data$A=unlist(sapply(strsplit(data$A, ":"), function(x){x=paste(x[1], x[2],sep=":")})) 
data$B=unlist(sapply(strsplit(data$B, ":"), function(x){x=paste(x[1], x[2],sep=":")}))
data$A.name = unlist(sapply(strsplit(data$A.name, ":"), function(x){x=paste(x[1], x[2],sep=":")})) #remove 3(4) -field for following analysis
data$B.name = unlist(sapply(strsplit(data$B.name, ":"), function(x){x=paste(x[1], x[2],sep=":")}))

print(head(data))

load(args[4])
if(any(-grep("E", data$A.name))){
  data = data[-grep("E", data$A.name),]
}

# ASSIGN SNP AND AMINO ACID INFORMATION
out = assign.SNP.PROT_prepare(data, nuc2dig, fam, "nuc")

out = assign.SNP.PROT(out)
NUC=out

out = assign.SNP.PROT_prepare(data, prot, fam, "prot")
out = assign.SNP.PROT(out)
PROT=out
 
data  =  rbind(HLA, NUC, PROT)
save(pred, file="tmp.RData")
save(data, file=paste0("imputation_", args[2],".RData"))                                    
