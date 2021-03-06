# INFO   : Script to run GWASpoly for tetraploides (modified from GWASpoly sources)
# AUTHOR : Luis Garreta (lgarreta@agrosavia.co)
# DATA   : Feb/2020
# LOG    :
	# r1.02:  Hidden warnigns qchisq
	# r1.01:  Removed annotations from functions. Output results to "out/" dir 
#-------------------------------------------------------------
#-------------------------------------------------------------
runGwaspGwas <- function (params) 
{
	msgmsg("Running GWASpoly...")

	genotypeFile  = params$genotypeFile
	phenotypeFile = params$phenotypeFile

	if (LOAD_DATA & file.exists ("gwas.RData")) load (file="gwas.RData")

	# Only for tetra ployds
	ploidy = 4

	#snpModels=testModels = ("general")
	snpModels  = c("general","additive","1-dom", "2-dom")
	testModels = c("general", "additive","1-dom-alt","1-dom-ref","2-dom-alt","2-dom-ref")

	params = append (params, list (snpModels=snpModels, testModels=testModels))

	# Read input genotype and genotype (format: "numeric", "AB", or "ACGT")
	data1 <- initGWAS (phenotypeFile, genotypeFile, ploidy, "ACGT", data1)

	# Control population structure
	data2 = controlPopulationStratification (data1, params$gwasModel, data2)

	# GWAS execution
	data3 <- runGwaspoly (data2, params$gwasModel, params$snpModels, data3)
	showResults (data3, params$testModels, params$trait, params$gwasModel, 
				 params$phenotypeFile, ploidy)

	if (LOAD_DATA) save(data, data1, data2, data3, file="gwas.RData") 
 }

#-------------------------------------------------------------
# Control population structure using default Kinship and PCs
#-------------------------------------------------------------
controlPopulationStratification <- function (data1, gwasModel, data2) 
{
	msgmsg ();msgmsg("Controlling populations structure...")

 	# Load data instead calculate it
	if (!is.null (data2)) {msgmsg(">>>> Loading kinship..."); return (data2) }

	if (gwasModel=="Naive") {
		msgmsg("    >>>> Without any correction") 
		markers = data1@pheno [,1]
		n       = length (markers)
		kinshipMatrix = matrix (diag (n), n, n, dimnames=list (markers, markers))
		dataTmp      <- set.K (data1, K=kinshipMatrix)
		#dataTmp      <- set.K (data1, K=NULL)
		data2        = new ("GWASpolyStruct", dataTmp)
	}else if (gwasModel == "Full") {
		msgmsg("    >>>> Using default Kinship and PCs=5 ")
		kinshipMatrix = NULL
		dataTmp       = set.K (data1)
		data2         = new ("GWASpolyStruct", dataTmp)
		data2@params  = set.params (n.PC=5, fixed=NULL, fixed.type=NULL)
	}else 
		stop ("unknown ploidy number (only 2 or 4)")

	return (data2)
}

#-------------------------------------------------------------
# GWAS execution
#-------------------------------------------------------------
runGwaspoly <- function (data2, gwasModel, snpModels, data3) 
{
	if (!is.null (data3)) { msgmsg(">>>> Loading GWASpoly..."); return (data3) }

 	if (gwasModel %in% c("Naive","Kinship")) {
		msgmsg(">>>> Without params")
		data3 = GWASpoly(data2, models=snpModels, traits=NULL, params=NULL, n.core=4)
	}else {
		msgmsg(">>>> With params")
		data3 = GWASpoly(data2, models=snpModels, traits=NULL, params=data2@params)
	}
	
	return (data3)
}

#-------------------------------------------------------------
# Plot results
#-------------------------------------------------------------
showResults <- function (data3, testModels, trait, gwasModel, correctionMethod, phenotypeFile, ploidy) 
{
	msgmsg ();msgmsg("Writing GWASpoly results...")
	outputDir  = "out/"
	outFile    = paste0 ("out/tool-GWASpoly-scores-", gwasModel)
	scoresFile = paste0 (outFile,".csv")
	plotFile   = paste0 ("out/out-GWASpoly-", gwasModel, "-plots.pdf") 

	msgmsg(">>>> Plotting results to ", outputDir, "...")
	#phenoName = strsplit (phenotypeFile, split=".scores")[[1]][1]

	n = length (testModels)
	
	# QTL Detection
	data5 = set.threshold (data3, method=correctionMethod,level=0.05,n.core=4)

	# Plots
	#plotName = sprintf("%s/%s-%s-plots.pdf", outputDir, outFile, gwasModel)
	#pdf (paste0 (outputDir, "/out-multiGWAS-manhattanQQ-plots.pdf"), width=11, height=15)
	pdf (file=plotFile, width=11, height=15)
	# QQ plot 
	#op <- par(mfrow = c(2,n), oma=c(0,0,3,0), mgp= c(2.2,1,0))
	#op <- par(mfrow = c(n,2), mar=c(3.5,3.5,3,1), oma=c(0,0,0,0), mgp = c(2.2,1,0)) #MultiGWAS tools
	#op <- par(mfrow = c(n,2), oma=c(0,0,3,0), mgp= c(2.2,1,0))
	op <- par(mfrow = c(n,2), mar=c(3.5,3.5,2,1), oma=c(0,0,0,0), mgp = c(2.2,1,0)) #MultiGWAS tools
	for (i in 1:length(testModels)) {
		manhattan.plot (data5, trait=trait, model=testModels [i])
		qqPlot(data3,trait=trait, model=testModels[i], cex=0.3)
	}

	plotTitle = sprintf ("%s gwas %s-ploidy for %s trait", gwasModel, ploidy, trait)  
	mtext(plotTitle, outer=T,  cex=1.5,  line=0)
	par(op)
	dev.off()

	msgmsg(">>>> Writing QTLs to file: ", scoresFile, "...")
	#write.GWASpoly (data5, trait, paste0(scoresFile,".qtls"), "scores", delim="\t")

	outQTLsAllSNPs  = getQTL (data5, gwasModel, ploidy)
	write.table (file=scoresFile, outQTLsAllSNPs, quote=F, sep="\t", row.names=F)

}



#-------------------------------------------------------------
# Plot results
#-------------------------------------------------------------
old_showResults <- function (data3, testModels, trait, gwasModel, correctionMethod, phenotypeFile, ploidy) 
{
	msgmsg ();msgmsg("Writing GWASpoly results...")
	outputDir  = "out/"
	outFile    = paste0 ("out/tool-GWASpoly-scores-", gwasModel)
	scoresFile = paste0 (outFile,".csv")
	plotFile   = paste0 ("out/out-GWASpoly-", gwasModel, "-plots.pdf") 

	msgmsg(">>>> Plotting results to ", outputDir, "...")
	#phenoName = strsplit (phenotypeFile, split=".scores")[[1]][1]

	n = length (testModels)
	
	# QTL Detection
	data5 = set.threshold (data3, method=correctionMethod,level=0.05,n.core=4)

	# Plots
	#plotName = sprintf("%s/%s-%s-plots.pdf", outputDir, outFile, gwasModel)
	pdf (file=plotFile, width=11, height=7)
	# QQ plot 
	op <- par(mfrow = c(2,n), oma=c(0,0,3,0), mgp= c(2.2,1,0))
	for (i in 1:length(testModels)) {
		#par (cex.main=0.5, cex.lab=0.5, cex.axis=0.5, ann=T)
		qqPlot(data3,trait=trait, model=testModels[i], cex=0.3)
	}

	# Manhattan plot 
	for (i in 1:length(testModels)) {
		#par (cex=1.5)
		#manhattan.plot (y.max=20,data5, trait=trait, model=testModels [i])
		manhattan.plot (data5, trait=trait, model=testModels [i])
	}
	plotTitle = sprintf ("%s gwas %s-ploidy for %s trait", gwasModel, ploidy, trait)  
	mtext(plotTitle, outer=T,  cex=1.5,  line=0)
	par(op)
	dev.off()

	msgmsg(">>>> Writing QTLs to file: ", scoresFile, "...")
	#write.GWASpoly (data5, trait, paste0(scoresFile,".qtls"), "scores", delim="\t")

	outQTLsAllSNPs  = getQTL (data5, gwasModel, ploidy)
	write.table (file=scoresFile, outQTLsAllSNPs, quote=F, sep="\t", row.names=F)

}


#-------------------------------------------------------------
# Extracts significant QTL
#-------------------------------------------------------------
getQTL <- function(data,gwasModel, ploidy, traits=NULL,models=NULL) 
{
	stopifnot(inherits(data,"GWASpoly.thresh"))

	if (is.null(traits)) traits <- names(data@scores)
	else stopifnot(is.element(traits,names(data@scores)))

	if (is.null(models)) models <- colnames(data@scores[[1]])
	else stopifnot(is.element(models,colnames(data@scores[[1]])))

	n.model <- length(models)
	n.trait <- length(traits)
	output <- data.frame(NULL)
	for (j in 1:n.model) {
		#ix <- which(data@scores[[traits[1]]][,models[j]] > (data@threshold[traits[1],models[j]]) - 1)
		ix <- which (data@scores[[traits[1]]][,models[j]] != 0)
		markers <-  data.frame (SNP=data@map[ix,c("Marker")])

		scores <- data@scores[[1]][,models[j]]
		datax = calculateInflationFactor (scores)

		n.ix <- length(ix)
		
		gc=rep(datax$delta,n.ix) 
		scores=round(data@scores[[traits[1]]][ix,models[j]],2)
		thresholds=round(rep(data@threshold[traits[1],models[j]],n.ix),2)
		diffs = (scores - thresholds)
		pvalues = 10^(-scores)
		df = data.frame(Ploidy=rep (ploidy, n.ix),
						Type=rep (gwasModel, n.ix),
						data@map[ix,],
						GC=gc,
						Model=rep(models[j],n.ix),
						P=pvalues,SCORE=scores, THRESHOLD=thresholds, DIFF=diffs,
						Effect=round(data@effects[[traits[1]]][ix,models[j]],2))
						#stringsAsFactors=F,check.names=F)

		output <- rbind(output, df)
	}
	#out <-cbind (Type=gwasModel, output)
	output <- output [order(-output$GC, -output$DIFF),]
	#output = output [!duplicated (output$Marker),]
	outputPositives = output [output$DIFF > 0,]
	outputNegatives = output [output$DIFF <= 0,]

	outQTLsAllSNPs = rbind (outputPositives, outputNegatives)

	return(outQTLsAllSNPs)
}

#-------------------------------------------------------------
# Calculate the inflation factor from -log10 values
# It can fire warning, here they are hidign
#-------------------------------------------------------------
calculateInflationFactor <- function (scores)
{
	oldw <- getOption("warn")
	options(warn = -1)

	remove <- which(is.na(scores))
	if (length(remove)>0) 
		x <- sort(scores[-remove],decreasing=TRUE)
	else 
		x <- sort(scores,decreasing=TRUE)

	pvalues = 10^-x
	chisq <- na.omit (qchisq(1-pvalues,1))
	delta  = round (median(chisq)/qchisq(0.5,1), 3)

	options (warn = oldw)

	return (list(delta=delta, scores=x))
}

#-------------------------------------------------------------
# QQ plot
#-------------------------------------------------------------
qqPlot <- function(data,trait,model,cex=1,filename=NULL) 
{
	stopifnot(inherits(data,"GWASpoly.fitted"))
	traits <- names(data@scores)

	stopifnot(is.element(trait,traits))
	models <- colnames(data@scores[[trait]])
	stopifnot(is.element(model,models))
	scores <- data@scores[[trait]][,model]

	datax = calculateInflationFactor (scores)

	n <- length(datax$scores)
	unif.p <- -log10(ppoints(n))
	if (!is.null(filename)) {postscript(file=filename,horizontal=FALSE)}
	par(pty="s")
	plot(unif.p, datax$scores, pch=16,cex=cex,
		 xlab=expression(paste("Expected -log"[10],"(p)",sep="")),
		 ylab=expression(paste("Observed -log"[10],"(p)",sep="")),
		 main=paste(trait," (",model,") ",sep=""))

	mtext (bquote(lambda[GC] == .(datax$delta)), side=3, line=-2, cex=0.7)

	lines(c(0,max(unif.p)),c(0,max(unif.p)),lty=2)
	if (!is.null(filename)) {dev.off()}
	return(datax$delta)
}

#-------------------------------------------------------------
# Read input genotype and genotype (format: "numeric", "AB", or "ACGT")
#-------------------------------------------------------------
initGWAS <- function (phenotypeFile, genotypeFile, ploidy, format="ACGT", data1) 
{
	msgmsg ();msgmsg("Initializing GWAS...");msgmsg ()
	# When data is previously loaded
	if (!is.null (data)) {msgmsg(">>>> Loading GWAS data..."); return (data)}

	data1 <- read.GWASpoly (ploidy = ploidy, pheno.file = phenotypeFile, 
							geno.file = genotypeFile, format = "ACGT", n.traits = 1, delim=",")

	return (data1)
}
#-------------------------------------------------------------
# Add label to filename
#-------------------------------------------------------------
addLabel <- function (filename, label)  {
	nameext = strsplit (filename, split="[.]")
	newName = paste0 (nameext [[1]][1], "-", label, ".", nameext [[1]][2])
	return (newName)
}
