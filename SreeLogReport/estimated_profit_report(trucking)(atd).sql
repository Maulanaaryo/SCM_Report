declare @ShipperType uniqueidentifier
declare @ConsingeeType uniqueidentifier
Declare @CarrierType uniqueidentifier

Declare @InternalExternal varchar(20)
Declare @FromDate Varchar(20)
Declare @ToDate Varchar(20)
Declare @FromDt DateTime
declare @ToDt DateTime


SET @FromDate #~3$ET$@FROMDATE$T$MN~#
SET @ToDate #~4$ET$@TODATE$T$MN~#
SET @InternalExternal #~6$ET$@INTERNALEXTERNAL$T$MN~#



---------------- LOGIC ---------------------------------
If(@FromDate <> '')
	SET @FromDt = Cast(@FromDate as DateTime)
else
    SET @FromDt = '2023-11-01' -- the data with the earliest date is Nov 8 2023
If(@ToDate <> '')
	SET @ToDt = Cast(@ToDate as DateTime)
else
    Set @ToDt = dbo.fn_getStartEndDate('Today', 'To') -- Today


select @ShipperType = Id from Sys_PartyTypes where Code = 'Shipper'
select @ConsingeeType = Id from Sys_PartyTypes where Code = 'Consignee'
select @CarrierType = id from Sys_PartyTypes where Code = 'ShippingLine'



---- Booking Details 
select Distinct COff.Code 'Office', Client.Name 'Client', SLPIC.Contact_Email 'SalesPIC', BI.BookingNumber 'BookingNo', BI.BookingDate 'BookingDate',Bi.Status 'BookingStatus', 
BP.Code 'JobType', BP.ProcessNumber 'JobNo', ShipperParty.Name 'Shipper', ConsigneeParty.Name 'Consignee',
BP.Status 'JobStatus', BP.CreatedBy 'JobCreatedBy', BP.CreatedOn 'JobCreatedOn',
BS.ETDDatetime 'ETD', BS.ETADatetime 'ETA', BS.ATDDatetime 'ATD', BS.ATADatetime 'ATA',
convert(varchar(12), dbo.fn_TimeZone(BI.ETDDatetime, BI.ETDTimeZoneId), 106) 'RSD',
ShippingLineParty.Name 'Carrier', BS.WayBillNo 'MAWB', BS.WayBillDate 'MAWBDate', BS.HouseWayBillNo 'HAWB', BS.HouseWayBillDate 'HAWBDate',
PL.Code 'PortOfLoadingCode', PL.Name 'PortOfLoadingName',
PD.Code 'PortOfDischargeCode', PD.Name 'PortOfDischargeName',
POR.Code 'PlaceOfReceiptCode', POR.Name 'PlaceOfReceiptName',
POD.Code 'PlaceOfDeliveryCode', POD.Name 'PlaceOfDeliveryName',
OCountry.Name 'CountryOfOrigin', DCountry.Name 'CountryOfDestination', 
BS.TotalPackages, PackageUOM.Name 'PackageUOM',
BS.NetWeight 'TotalNetWeight', BS.GrossWeight 'TotalGrossWeight', BS.ChargeableWeight 'Total Chargable Weight',
WeightUOM.Code 'TotalWeightUOM', BS.VolumeValue 'TotalVolume', VolumeUOM.Code 'TotalVolumeUOM',
BS.VesselName, BS.VoyageNo, BS.VoyageDateDateTime 'VesselVoyageDate',

	Bs.CarrierBookingReferenceNumber 'CarrierBookingNo',
	Bi.id Bookingid,bp.id Bookingprocessid,BS.Id BookingserviceId,ss.code as servicecode,
	SM.Name as ShipmentMode,salespicNAME,BP.ProcessNumberGeneratedDate 'ExeDate',

-- UserDefined Field
cf.[Open Date CY],cf.[Close Date CY],[Internal-External]
	

Into #BookingDetails
from Bkg_BookingInfo BI WITH (NOLOCK) 
	left join Bkg_BookingProcess BP WITH (NOLOCK) on BP.BookingInfoId = bi.id
	LEFT JOIN cust_office cOff WITH (NOLOCK) ON cOff.Id = BP.OwnerOfficeId AND cOff.IsActive = 1 AND cOff.IsDeleted = 0
	LEFT JOIN Sys_TransportationMode TSMode WITH (NOLOCK) ON BP.TransportationModeId = TSMode.Id AND tsMode.IsActive = 1
	Left JOIN Bkg_BookingService BS WITH (NOLOCK) ON BP.BookingServiceId = bs.Id AND bs.IsDeleted = 0 AND bs.IsActive = 1
		LEFT JOIN Bkg_BookingParty ShipperParty ON BS.Id = ShipperParty.BookingServiceId 
			AND ShipperParty.PartyTypeId = @ShipperType and ShipperParty.IsDeleted = 0
		LEFT JOIN Bkg_BookingParty ConsigneeParty ON BS.Id = ConsigneeParty.BookingServiceId 
			AND ConsigneeParty.PartyTypeId = @ConsingeeType and ConsigneeParty.IsDeleted = 0
		LEFT JOIN Bkg_BookingParty ShippingLineParty ON BS.Id = ShippingLineParty.BookingServiceId 
			AND ShippingLineParty.PartyTypeId = @CarrierType and ShippingLineParty.IsDeleted = 0
		
		LEFT JOIN Cust_Location PL WITH (NOLOCK) ON PL.ID = BS.portofLoadingId
		LEFT JOIN Cust_Location PD WITH (NOLOCK) ON PD.ID = BS.PortOfDischargeId
		LEFT JOIN Cust_Location POR WITH (NOLOCK) ON POR.ID = BS.portofLoadingId
		LEFT JOIN Cust_Location POD WITH (NOLOCK) ON POD.ID = BS.PortOfDischargeId
		LEFT JOIN Sys_UOM WeightUOM WITH (NOLOCK) ON WeightUOM.ID = BS.[WeightUOMId]
		LEFT JOIN Sys_UOM VolumeUOM WITH (NOLOCK) ON VolumeUOM.ID = BS.VolumeUOMId
		LEFT JOIN Cust_Country OCountry WITH (NOLOCK) on BS.CountryOfOriginId = OCountry.Id
		LEFT JOIN Cust_Country DCountry WITH (NOLOCK) on BS.CountryOfDestinationId = DCountry.Id
   		LEFT JOIN Sys_UOM PackageUOM WITH (NOLOCK) ON BS.PackageUOMId = PackageUOM.Id AND PackageUOM.UOMType = 'Packages'
	
		LEFT JOIN cust_clients Client WITH (NOLOCK) ON BI.ClientId = Client.Id AND client.IsActive = 1 AND Client.IsDeleted = 0
	LEFT JOIN Bkg_BookingActivity ACT ON ACT.BookingProcessId = BP.Id AND ACT.IsDeleted = 0
	LEFT JOIN Sys_Process SYSPROC WITH(NOLOCK) ON SYSPROC.Id = BP.ProcessId
	left join Sys_Service SS with(nolock) on ss.id = bs.ServiceId
	left join Sys_ShipmentMode SM with(nolock) on SM.id = bi.ShipmentModeId

	--Custom fields
Left join (select * from (
								Select Processnumber,Bi.bookingnumber,EntityId,Entity,	DisplayName 'UDF', 	ef.FieldValue 'Value'
								from Cust_ExtensionFields EF left join Cust_ExtensionFieldMetaData EFMD
								on EFMD.Id = ef.ExtensionFieldMetaDataId Left join  Bkg_BookingProcess BP on bp.id = ef.EntityId left join Bkg_BookingInfo BI on BI.id = bp.BookingInfoId
								where bi.BookingNumber is not null and Entity = 'Sea'
								) src
								pivot(	min ([Value])	for [UDF] in ([Open Date CY],[Close Date CY],[Vessel Name])) piv 	
				) as CF 
on CF.BookingNumber = bi.BookingNumber and cf.ProcessNumber = bp.ProcessNumber

Left join (select * from (
		Select Bi.bookingnumber,EntityId,Entity,	DisplayName 'UDF', 	ef.FieldValue 'Value'
		from Cust_ExtensionFields EF 
		left join Cust_ExtensionFieldMetaData EFMD	on EFMD.Id = ef.ExtensionFieldMetaDataId 
		left join Bkg_BookingInfo BI on BI.id = ef.EntityId
		where bi.BookingNumber is not null 
		) src
		pivot(	min ([Value])	for [UDF] in ([Open Date CY],[Close Date CY],[Internal-External])) piv 	
		) as BCF 
on BCF.BookingNumber = bi.BookingNumber

-- Sales PIC
left join (Select Bi.Id,  cr.Contact_PersonName_FirstName +  ' ' + cr.Contact_PersonName_LastName as Contact_Email,cr.Contact_PersonName_FirstName + ' ' + cr.Contact_PersonName_LastName AS salespicNAME from 
Bkg_BookingTeam BT with(nolock) 
inner join Bkg_BookingInfo BI with(nolock) on BI.id = bt.BookingInfoId and bt.IsDeleted = 0  
inner join Cust_ResOfficeResFuncMap RORF with(nolock) on RORF.Id = bt.ResOfficeResFuncMapId
inner join Cust_Resource CR with(nolock) on cr.Id = bt.ResourceId
inner join Sys_ResourceFunction RF with(nolock) on rf.Id = rorf.ResourceFunctionId and rf.id = '457d6ee0-e130-4948-8359-3a7c3ca38a51') as SLPIC
on SLPIC.id = bi.Id

	WHERE ShipperParty.Name is not null
		and bi.Status = 'Confirmed'
	    AND (BP.ProcessNumberGeneratedDate BETWEEN @FromDt AND @ToDt) -- Executed Date
		AND (@InternalExternal = '' OR [Internal-External] = @InternalExternal)


-- Equipment Details 

-- Get Booking equipment details
select Distinct sj.BookingNo,bp.ProcessNumber,ces.code as Esize, Be.id as Ecount  into #Equipment 
from #BookingDetails sj with (Nolock)
left join Bkg_BookingProcess BP  with(nolock) on bp.BookingInfoId = sj.Bookingid and bp.id = sj.Bookingprocessid
left join Bkg_BookingEquipment bE with(Nolock) on be.BookingProcessId = bp.id and be.IsDeleted = 0 
left join Cust_Equipment CE with(Nolock) on ce.id = be.EquipmentId
left join Cust_EquipmentSize CES with(Nolock) on ces.id = ce.EquipmentSizeId
group by sj.BookingNo,bp.ProcessNumber,ces.code, Be.id 



select BookingNo,ProcessNumber,Esize, count(Ecount) as Ecount Into #EquipmentDetails 
from #Equipment group by BookingNo,ProcessNumber,Esize


update #EquipmentDetails set esize = 'Others' where esize not in ('20','40')
select *,Cast('' as varchar(30)) as ContainerSumamry  into #BkgEQPDetails from (	select BookingNo,ProcessNumber,Esize, Ecount as 'Value' from #EquipmentDetails
		) src
		pivot(	min ([Value])	for [Esize] in ([20],[40],[Others])) piv 



-- Job Sheet details 
select BJS.BookingProcessId, PartyId, Cp.code as partyCode,cp.Name as partyName,
ChargeCodeId , bcc.code as chargecode,bcc.Name as chargeName, EstChargeRate,
EstChargeCurrencyId, cc.Code as ChargeCurrency,
estchargeamount,BaseExchRate,EstBaseAmount, 
case when IsRevenue = 1 then 'Rev' else 'Cost' end as COSTREV , Bjs.Quantity
Into #JobsheetDetails from Bill_JobSheetCharge BJS with(Nolock)
left join Cust_Party cp on cp.id = bjs.PartyId 
left join Bill_ChargeCode BCC on BCC.id = bjs.ChargeCodeId
left join Cust_Currency CC on cc.id = bjs.EstChargeCurrencyId
left join Cust_Office CO on CO.id = bjs.OfficeId
join ( select Bookingprocessid  from #BookingDetails group by Bookingprocessid) BP on Bp.Bookingprocessid = bjs.BookingProcessId
where BJS.IsDeleted = 0 and co.Code = 'JKT'
and Bcc.Name LIKE '%trucking%'

-- Job Sheet Cost Revenue 
select bp.BookingNo, BJS.BookingProcessId, PartyId,
ChargeCodeId , EstChargeRate,
EstChargeCurrencyId,
estchargeamount,BaseExchRate,EstBaseAmount, 
case when IsRevenue = 1 then 'Rev' else 'Cost' end as COSTREV , Bjs.Quantity
Into #JobsheetCostRev from Bill_JobSheetCharge BJS with(Nolock)
left join Cust_Office CO on CO.id = bjs.OfficeId
join ( select BookingNo,Bookingprocessid  from #BookingDetails group by Bookingprocessid,BookingNo) BP on Bp.Bookingprocessid = bjs.BookingProcessId
where BJS.IsDeleted = 0 and co.Code = 'JKT'

SELECT
  BookingNo,
  SUM(CASE WHEN COSTREV = 'Cost' THEN EstBaseAmount ELSE 0 END) AS CostTotal,
  SUM(CASE WHEN COSTREV = 'Rev' THEN EstBaseAmount ELSE 0 END) AS RevenueTotal,
  SUM(CASE WHEN COSTREV = 'Rev' THEN EstBaseAmount ELSE 0 END) 
  - SUM(CASE WHEN COSTREV = 'Cost' THEN EstBaseAmount ELSE 0 END) AS ProfitTotal
INTO #TempCostRevTotals
FROM #JobsheetCostRev
GROUP BY BookingNo

Select  BookingProcessId, Cast('' as varchar(120)) as [Internal-External], Cast('' as varchar(120)) as SalesPIC, Cast('' as varchar(120)) as MBL, Cast('' as DateTime) as ExeDate, Cast('' as DateTime) as ATD, Cast('' as varchar(120)) as ProcessNumber,Cast('' as varchar(120)) as BookingNo, Cast('' as varchar(120)) as Carrier,Cast('' as varchar(120)) as POL, Cast('' as varchar(120)) as POD,Cast('' as varchar(120)) as Customer,Cast(0 as int) as [20],Cast(0 as int) as [40],Cast(0 as int) as [Other],
partyName,chargecode,chargeName,EstChargeRate 'CostRate',ChargeCurrency 'CostCurrency',Quantity 'CostQty', estchargeamount 'CostAmount' ,BaseExchRate 'CostExchRate',EstBaseAmount 'CostBaseRate',
0 'RevRate',Cast('' as varchar(120))  'RevCurrency', 0 as 'RevQty',0'RevAmount' ,0'RevExchRate',0 'RevBaseRate'
Into #CarrierDetails from #JobsheetDetails where COSTREV = 'Cost'

insert  Into #CarrierDetails
Select  BookingProcessId, Cast('' as varchar(120)) as [Internal-External], Cast('' as varchar(120)) as SalesPIC, Cast('' as varchar(120)) as MBL, Cast('' as DateTime) as ExeDate, Cast('' as DateTime) as ATD, Cast('' as varchar(120)) as ProcessNumber,Cast('' as varchar(120)) as BookingNo,Cast('' as varchar(120)) as Carrier,Cast('' as varchar(120)) as POL, Cast('' as varchar(120)) as POD,Cast('' as varchar(120)) as Customer,Cast(0 as int) as [20],Cast(0 as int) as [40],Cast(0 as int) as [Other],
partyName,chargecode,chargeName,0 'CostRate',Cast('' as varchar(120)) 'CostCurrency',0 as 'CostQty', 0 'CostAmount' ,0 'CostExchRate',0 'CostBaseRate',
EstChargeRate 'RevRate',ChargeCurrency 'RevCurrency', Quantity as 'RevQty', estchargeamount 'RevAmount' ,BaseExchRate 'RevExchRate',EstBaseAmount 'RevBaseRate'
 from #JobsheetDetails where COSTREV = 'Rev'

update #CarrierDetails set #CarrierDetails.[Internal-External] = #BookingDetails.[Internal-External], #CarrierDetails.SalesPIC = #BookingDetails.SalesPIC, #CarrierDetails.MBL = #BookingDetails.MAWB ,#CarrierDetails.ExeDate = #BookingDetails.ExeDate, #CarrierDetails.ATD = #BookingDetails.ATD, #CarrierDetails.Carrier = #BookingDetails.Carrier ,POL = PortOfLoadingName , POD = PortOfDischargeName,Customer = Client,
ProcessNumber = #BookingDetails.JobNo, BookingNo = #BookingDetails.BookingNo
from #BookingDetails where #CarrierDetails.BookingProcessId = #BookingDetails.Bookingprocessid

update A set a.[20] = b.[20], a.[40]= b.[40] ,a.Other = b.Others
from #CarrierDetails as A, #BkgEQPDetails B
where a.ProcessNumber = b.ProcessNumber

-- select * from #CarrierDetails cd left join #TempCostRevTotals tc on tc.BookingNo = cd.BookingNo

;WITH ConsolidatedCarrierDetails AS (
  SELECT
    cd.BookingNo AS 'Book No',
    cd.ATD AS 'ATD',
    MIN(cd.ExeDate) AS 'Executed Date',
    MIN(cd.MBL) AS 'BL No',
    MIN(cd.Customer) AS Customer,
    MIN(cd.SalesPIC) AS 'Sales',
    MIN(cd.[Internal-External]) AS [Internal-External],
    MIN(cd.POL) AS POL,
    MIN(cd.POD) AS POD,
    STRING_AGG(cd.Carrier, '/') WITHIN GROUP (ORDER BY cd.Carrier) AS 'Liner',
    MAX(cd.[20]) AS 'QTY 20',
    MAX(cd.[40]) AS 'QTY 40',
    MAX(cd.[Other]) AS 'QTY Other',
    MAX(cd.CostCurrency) AS 'Buy Currency',
    SUM(CASE
          WHEN cd.[20] <> 0 THEN cd.CostRate * cd.[20]
          WHEN cd.[40] <> 0 THEN cd.CostRate * cd.[40]
          WHEN cd.[Other] <> 0 THEN cd.CostRate * cd.[Other]
          ELSE 0
        END) AS 'Buy per FCL',
    MAX(cd.CostExchRate) AS 'Exc Buy',
    SUM(CASE WHEN cd.CostCurrency = 'USD' THEN 
          CASE
            WHEN cd.[20] <> 0 THEN cd.CostRate * cd.CostExchRate * cd.[20]
            WHEN cd.[40] <> 0 THEN cd.CostRate * cd.CostExchRate * cd.[40]
            WHEN cd.[Other] <> 0 THEN cd.CostRate * cd.CostExchRate * cd.[Other]
            ELSE 0
          END
        ELSE 0 END) AS 'Buy per FCL (IDR)',
    MAX(tc.CostTotal) AS 'Buy Total',  -- Ensuring it does not double the cost
    MAX(cd.RevCurrency) AS 'Sell Currency',
    SUM(CASE
          WHEN cd.[20] <> 0 THEN cd.RevRate * cd.[20]
          WHEN cd.[40] <> 0 THEN cd.RevRate * cd.[40]
          WHEN cd.[Other] <> 0 THEN cd.RevRate * cd.[Other]
          ELSE 0
        END) AS 'Sell per FCL',
    MAX(cd.RevExchRate) AS 'Exc Sell',
    SUM(CASE WHEN cd.RevCurrency = 'USD' THEN 
          CASE
            WHEN cd.[20] <> 0 THEN cd.RevRate * cd.RevExchRate * cd.[20]
            WHEN cd.[40] <> 0 THEN cd.RevRate * cd.RevExchRate * cd.[40]
            WHEN cd.[Other] <> 0 THEN cd.RevRate * cd.RevExchRate * cd.[Other]
            ELSE 0
          END
        ELSE 0 END) AS 'Sell per FCL (IDR)',
    MAX(tc.RevenueTotal) AS 'Sell Total',  -- Using MAX to avoid doubling the value
    CASE 
      WHEN MAX(cd.CostCurrency) = 'USD' AND MAX(cd.RevCurrency) = 'USD'
      THEN (SUM(cd.RevRate) - SUM(cd.CostRate)) * 
           CASE
             WHEN MAX(cd.[20]) > 0 THEN MAX(cd.[20])
             WHEN MAX(cd.[40]) > 0 THEN MAX(cd.[40])
             ELSE MAX(cd.[Other])
           END
      ELSE NULL 
    END AS 'Freight Profit (USD)',
    MAX(tc.ProfitTotal) AS 'Total Profit'  -- Ensuring Profit Total is also not doubled
  FROM #CarrierDetails cd
  LEFT JOIN #TempCostRevTotals tc ON tc.BookingNo = cd.BookingNo
  GROUP BY cd.BookingNo, cd.ATD
)
SELECT 
  *
FROM 
  ConsolidatedCarrierDetails
ORDER BY 
  [Executed Date], [Book No];

-- Clean up temp tables if necessary
DROP TABLE IF EXISTS #CarrierDetails, #JobsheetDetails, #TempCostRevTotals
