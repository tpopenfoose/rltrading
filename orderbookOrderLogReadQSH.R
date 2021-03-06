library(data.table)
library(bit64)
options(digits.secs=3)

fname<-"~/repos/DATA/"
setwd(fname)
#Header 
# Received;ExchTime;OrderId;Price;Amount;AmountRest;DealId;DealPrice;OI;Flags
fname<-"OrdLog.Si-3.16.2016-02-12.{1-OrdLog}.txt"
orderlog<-fread(fname,skip=3, sep=";",stringsAsFactors=FALSE, header=FALSE)# nrows=1000000)


header<-c("Received",
          "ExchTime",
          "OrderId",
          "Price",
          "Amount",
          "AmountRest",
          "DealId",
          "DealPrice",
          "OI",
          "Flags")
setnames(orderlog, header)

flags<-c("NonZeroReplAct",
         "SessIdChanged",
         "Add",
         "Fill",
         "Buy",
         "Sell",
         "Quote",
         "Counter",
         "NonSystem",
         "EndOfTransaction",
         "FillOrKill",
         "Moved",
         "Canceled",
         "CanceledGroup",
         "CrossTrade")

orderlog[,c(flags):= lapply(c(flags), function(x) grepl(x,Flags))]
orderlog[,"Fill" := grepl("Fill,",Flags)]
dtFormat<-"%d.%m.%Y %H:%M:%OS"
orderlog[,"datetime":=as.POSIXct(strptime(ExchTime,dtFormat))]
orderlog<-orderlog[datetime>=as.POSIXct(paste(format(orderlog[.N,datetime], "%Y-%m-%d"),
                                              "10:00:00.000"))]
#orderlog[,"id":=1:.N]
#orderlog[,"pid":=id]
# Remove NonSystem orders
orderlog<-orderlog[,Active:=sum(NonSystem)==0,by=OrderId][Active==TRUE]
orderlog[,"Active":=NA]


##########NEW################################3
getBA<-function(orderlogDT){
    orderlogDT[, Active:=sum(Fill)==0 &
                   sum(Canceled)==0 &
                   sum(CrossTrade)==0 &
                   sum(AmountRest==0)==0, by=OrderId][Active==TRUE,as.list(c(.SD[Buy==TRUE][,sum(AmountRest), by=Price][order(-Price)][1:3,c(Price,V1)],
                                                                             .SD[Sell==TRUE][,sum(AmountRest), by=Price][order(Price)][1:3,c(Price,V1)]))]                             
    
}

startTime<-Sys.time()
#baDT<-orderlog[][,getBA(orderlog[datetime<.BY[[1]]]), by=datetime]
setkey(orderlog, datetime)
baDT<-unique(orderlog, by="datetime",fromLast=TRUE)[,pid:=id][,getBA(orderlog[1:pid,]),by=datetime]
tickDT<-orderlog[][DealId>0 & EndOfTransaction,.(datetime, DealPrice, Amount), by=DealId]

banames<-c("datetime", "bidprice0","bidprice1", "bidprice2",
           "bidvolume0","bidvolume1","bidvolume2","askprice0","askprice1","askprice2",
           "askvolume0","askvolume1","askvolume2")
setnames(baDT, banames)
Sys.time()-startTime

setkey(tickDT, datetime)
setkey(baDT, datetime)
tbaDT<-baDT[tickDT,roll=T]



library(ggplot2)
ggplot(data=tbaDT)+
    geom_line(aes(datetime,DealPrice), colour="darkgrey")+
    geom_line(aes(datetime,askprice0), coloordur="lightcoral", alpha=I(0.5))+
    geom_line(aes(datetime,bidprice0), colour="mediumaquamarine",alpha=I(0.5))

# makeBidAsk<-function(orderlogrow, depth=3, bytick=TRUE){
#   orderbook<<-rbindlist(list(orderbook, orderlogrow))
#   if(orderlogrow[,Fill]==bytick){
#     orderbook<<-orderbook[, Active:=sum(Fill)==0 &
#                            sum(Canceled)==0 &
#                            sum(CrossTrade)==0 &
#                            sum(AmountRest==0)==0, by=OrderId][Active==TRUE]
# 
#     cat("\r",paste(100*orderlogrow[,pid]/nrow(orderlog),"%"))
#     
#     bidaskrow<-c(orderbook[Buy==TRUE][,sum(AmountRest), by=Price][order(-Price)][1:3][,c(t(Price),t(V1))],
#                  orderbook[Sell==TRUE][,sum(AmountRest),by=Price][order(Price)][1:3][,c(t(Price),t(V1))])
#     as.list(bidaskrow)
#     #tickbidaskdt<-rbindlist(list(tickbidaskdt, as.list(bidaskrow)))
#   }
# }
# orderbook<-data.table()
# tickbidaskdt<-orderlog[,makeBidAsk(.SD, bytick=FALSE), by=id]
# ticks<-orderlog[Fill==TRUE]

banames<-c("id", "bidprice0","bidprice1", "bidprice2",
           "bidvolume0","bidvolume1","bidvolume2","askprice0","askprice1","askprice2",
           "askvolume0","askvolume1","askvolume2")
setnames(tickbidaskdt, banames)





tickbidaskdt<-cbind(tickbidaskdt,ticks)
tickbidaskdt<-tickbidaskdt[NonSystem!=TRUE]

dtFormat<-"%d.%m.%Y %H:%M:%OS"
tickbidaskdt[,"datetime":=as.POSIXct(strptime(ExchTime,dtFormat))]

tickbidaskdt[,buysell:=ifelse(Buy==TRUE, "Buy", "Sell")]

tbanames<-c("datetime", "DealPrice","Amount","buysell", "bidprice0","bidprice1", "bidprice2",
            "bidvolume0","bidvolume1","bidvolume2","askprice0","askprice1","askprice2",
            "askvolume0","askvolume1","askvolume2")


dfplaza<-tickbidaskdt[,.SD,.SDcols=tbanames]

dfnames<-c("datetime", "price","volume","buysell", "bidprice0","bidprice1", "bidprice2",
           "bidvolume0","bidvolume1","bidvolume2","askprice0","askprice1","askprice2",
           "askvolume0","askvolume1","askvolume2")

setnames(dfplaza, dfnames)
rm(tickbidaskdt,ticks)
gc()

dfdate<-format(dfplaza[.N,datetime], "%Y-%m-%d")
downlimit<-as.POSIXct(paste(dfdate,"10:00:00.000"))
uplimit<-as.POSIXct(paste(dfdate,"18:00:00.000"))
dfplaza<-dfplaza[datetime>downlimit & datetime<uplimit]

save(dfplaza, file="dfplaza.RData")




